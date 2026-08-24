-- =====================================================================
-- RentalMngr — Cuotas por usuario aplicadas en SERVIDOR
-- Fecha: 2026-08-21
-- Requiere haber ejecutado antes 20260821000001_monetizacion_y_limites.sql
-- No borra datos: solo bloquea inserciones que superen el plan.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Resolver de qué propietario es un fichero de storage.
--
-- OJO: conviven DOS esquemas de ruta y una política que asuma uno solo
-- deniega o deja pasar todo:
--   iOS     -> <room_id>/<archivo>.jpg            (UUID en MAYÚSCULAS)
--   webapp  -> room-photos/<property_id>/<room_id>/<archivo>
-- Los UUID de Swift van en mayúsculas; ::uuid los acepta igual.
-- ---------------------------------------------------------------------
create or replace function public.storage_object_owner(object_name text)
returns uuid language plpgsql stable security definer set search_path to 'public' as $$
declare
    parts text[] := storage.foldername(object_name);
    v_owner uuid;
begin
    if parts[1] = 'room-photos' then
        -- webapp: la segunda carpeta es la propiedad
        select owner_id into v_owner from properties where id = parts[2]::uuid;
    else
        -- iOS: la primera carpeta es la habitación
        select p.owner_id into v_owner
          from rooms r join properties p on p.id = r.property_id
         where r.id = parts[1]::uuid;
    end if;
    return v_owner;
exception when others then
    -- Ruta con formato inesperado: no se puede atribuir a nadie.
    return null;
end;
$$;

-- ---------------------------------------------------------------------
-- Cuota de FOTOS. Es el coste real por usuario: 909 KB de media por foto
-- y el plan Free de Supabase son 1 GB en total.
--   Gratis  ->  25 fotos
--   Premium -> 400 fotos
-- Más un tope diario anti-abuso en ambos planes.
-- ---------------------------------------------------------------------
create or replace function public.enforce_photo_quota()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare
    v_owner      uuid;
    v_premium    boolean;
    v_total      integer;
    v_today      integer;
    v_max_total  integer;
    v_max_daily  integer;
begin
    if NEW.bucket_id <> 'room-photos' then
        return NEW;
    end if;

    v_owner := storage_object_owner(NEW.name);
    -- Si no se puede atribuir, se cobra a quien sube.
    if v_owner is null then
        v_owner := auth.uid();
    end if;
    if v_owner is null then
        return NEW;  -- procesos de servidor
    end if;

    v_premium   := is_premium(v_owner);
    v_max_total := case when v_premium then 400 else 25 end;
    v_max_daily := case when v_premium then 100 else 25 end;

    select count(*) into v_total
      from storage.objects o
     where o.bucket_id = 'room-photos'
       and storage_object_owner(o.name) = v_owner;

    if v_total >= v_max_total then
        raise exception 'photo_quota_reached'
            using hint = 'Upgrade to premium for more photos';
    end if;

    select count(*) into v_today
      from storage.objects o
     where o.bucket_id = 'room-photos'
       and o.created_at > now() - interval '1 day'
       and storage_object_owner(o.name) = v_owner;

    if v_today >= v_max_daily then
        raise exception 'photo_daily_limit_reached'
            using hint = 'Daily upload limit reached, try again tomorrow';
    end if;

    return NEW;
end;
$$;

drop trigger if exists trg_enforce_photo_quota on storage.objects;
create trigger trg_enforce_photo_quota
    before insert on storage.objects
    for each row execute function public.enforce_photo_quota();

-- ---------------------------------------------------------------------
-- Cuota de DOCUMENTOS (5 gratis / 300 premium).
-- Hoy estos números viven como constantes en Swift que NADIE comprueba.
-- ---------------------------------------------------------------------
create or replace function public.enforce_document_quota()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare
    v_owner uuid;
    v_count integer;
    v_max   integer;
begin
    select owner_id into v_owner from properties where id = NEW.property_id;
    if v_owner is null then return NEW; end if;

    v_max := case when is_premium(v_owner) then 300 else 5 end;

    select count(*) into v_count
      from documents d join properties p on p.id = d.property_id
     where p.owner_id = v_owner;

    if v_count >= v_max then
        raise exception 'document_quota_reached'
            using hint = 'Upgrade to premium for more documents';
    end if;

    return NEW;
end;
$$;

drop trigger if exists trg_enforce_document_quota on public.documents;
create trigger trg_enforce_document_quota
    before insert on public.documents
    for each row execute function public.enforce_document_quota();

-- ---------------------------------------------------------------------
-- Índice de apoyo: la cuota diaria filtra por fecha de creación.
-- ---------------------------------------------------------------------
create index if not exists idx_storage_objects_bucket_created
    on storage.objects (bucket_id, created_at);

-- =====================================================================
-- ⚠️ NO EJECUTAR TODAVÍA — bucket privado
--
-- La app iOS ya usa URLs firmadas (verificado con fotos reales), y Android
-- también. Pero los 21 ficheros con prefijo `room-photos/` los subió la
-- WEBAPP, y no tengo visibilidad de si esa lee por URL pública. Si es así,
-- esto le rompe las imágenes.
--
-- Cuando lo confirmes, ejecuta:
--
-- update storage.buckets set public = false where id = 'room-photos';
--
-- create policy "room_photos_rw" on storage.objects
--   for all to authenticated
--   using      (bucket_id = 'room-photos' and storage_object_owner(name) is not distinct from auth.uid()
--               or exists (select 1 from property_access pa
--                          join rooms r on r.property_id = pa.property_id
--                          where pa.user_id = auth.uid()
--                            and r.id::text = lower((storage.foldername(name))[1])))
--   with check (bucket_id = 'room-photos' and storage_object_owner(name) is not null);
--
-- Para volver atrás: update storage.buckets set public = true where id = 'room-photos';
-- =====================================================================
