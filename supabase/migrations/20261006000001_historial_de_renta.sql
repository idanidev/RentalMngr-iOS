-- Historial de subidas de renta (RepoMind #24)
--
-- Hasta ahora la renta solo existía como valor actual, en tenants.monthly_rent
-- y rooms.monthly_rent. Al cambiarla se pisaba la anterior y no quedaba rastro
-- de cuándo ni de cuánto había subido.
--
-- QUÉ HACE AL APLICARSE: crea una tabla vacía, sus políticas y una función.
-- NO MODIFICA NINGUNA FILA EXISTENTE. Los datos solo cambian cuando alguien
-- registra una subida desde la app.
--
-- Se puede ejecutar más de una vez: todo comprueba antes de crear.
--
-- Vuelta atrás, si hiciera falta (borra el historial que se haya registrado):
--   drop function if exists public.record_rent_change(uuid, numeric, date, text);
--   drop table if exists public.rent_changes;

-- ── La tabla ──────────────────────────────────────────────────────────────

create table if not exists public.rent_changes (
    id              uuid primary key default gen_random_uuid(),
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    -- Para la RLS: los permisos van por propiedad, como en el resto de tablas.
    property_id     uuid not null references public.properties(id) on delete cascade,
    -- La habitación puede borrarse después; el historial se queda.
    room_id         uuid references public.rooms(id) on delete set null,
    previous_amount numeric(10, 2),
    new_amount      numeric(10, 2) not null check (new_amount >= 0),
    -- Desde cuándo rige la renta nueva.
    effective_date  date not null,
    note            text,
    created_by      uuid references auth.users(id) on delete set null default auth.uid(),
    created_at      timestamptz not null default now()
);

create index if not exists rent_changes_tenant_idx
    on public.rent_changes (tenant_id, effective_date desc);

alter table public.rent_changes enable row level security;

-- ── Políticas ─────────────────────────────────────────────────────────────
-- Las mismas funciones que usan rooms, tenants e income. Sin políticas de
-- UPDATE ni DELETE: el historial no se reescribe.

do $$
begin
    if not exists (select 1 from pg_policies
                   where schemaname = 'public' and tablename = 'rent_changes'
                     and policyname = 'rent_changes_select') then
        create policy rent_changes_select on public.rent_changes
            for select using (public.has_property_access(property_id));
    end if;

    if not exists (select 1 from pg_policies
                   where schemaname = 'public' and tablename = 'rent_changes'
                     and policyname = 'rent_changes_insert') then
        create policy rent_changes_insert on public.rent_changes
            for insert with check (public.can_edit_property(property_id));
    end if;
end $$;

-- ── Registrar una subida ──────────────────────────────────────────────────
-- Todo en una sola transacción: apunta el cambio, actualiza la renta del
-- inquilino y la de su habitación, y corrige los cobros PENDIENTES desde el mes
-- en que rige. Los cobros ya pagados no se tocan.
--
-- SECURITY INVOKER: corre con los permisos de quien llama, así que pasa por la
-- RLS de cada tabla. Un usuario de solo lectura no puede registrar subidas (la
-- inserción en rent_changes la rechaza can_edit_property) y no hace falta
-- comprobar nada a mano.

create or replace function public.record_rent_change(
    p_tenant_id      uuid,
    p_new_amount     numeric,
    p_effective_date date,
    p_note           text default null
)
returns public.rent_changes
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_tenant   public.tenants;
    v_room_id  uuid;
    v_previous numeric;
    v_row      public.rent_changes;
begin
    if p_new_amount is null or p_new_amount < 0 then
        raise exception 'invalid_amount';
    end if;
    if p_effective_date is null then
        raise exception 'invalid_effective_date';
    end if;

    -- La RLS de tenants ya filtra: si no lo ves, no existe para ti.
    select * into v_tenant from tenants where id = p_tenant_id;
    if not found then
        raise exception 'tenant_not_found';
    end if;

    select r.id, r.monthly_rent into v_room_id, v_previous
      from rooms r where r.tenant_id = v_tenant.id
      limit 1;
    -- Misma regla que effectiveMonthlyRent en la app: la de la habitación, y
    -- si no tiene, la del inquilino.
    v_previous := coalesce(v_previous, v_tenant.monthly_rent);

    if v_previous is not null and v_previous = p_new_amount then
        raise exception 'same_amount';
    end if;

    insert into rent_changes (tenant_id, property_id, room_id, previous_amount,
                              new_amount, effective_date, note)
    values (v_tenant.id, v_tenant.property_id, v_room_id, v_previous,
            p_new_amount, p_effective_date, nullif(trim(p_note), ''))
    returning * into v_row;

    update tenants
       set monthly_rent = p_new_amount, updated_at = now()
     where id = v_tenant.id;

    if v_room_id is not null then
        update rooms
           set monthly_rent = p_new_amount, updated_at = now()
         where id = v_room_id;

        update income
           set amount = p_new_amount, updated_at = now()
         where room_id = v_room_id
           and paid = false
           and month >= date_trunc('month', p_effective_date)::date;
    end if;

    return v_row;
end;
$$;

-- Nada para anon (docs/SQL_RULES.md): solo usuarios con sesión.
revoke all on function public.record_rent_change(uuid, numeric, date, text) from public, anon;
grant execute on function public.record_rent_change(uuid, numeric, date, text) to authenticated;
