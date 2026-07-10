-- Device tokens for APNs remote push.
-- Run this in the Supabase SQL editor (or via the CLI). NOT executed automatically.

create table if not exists public.device_tokens (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references auth.users(id) on delete cascade,
    token       text not null unique,
    platform    text not null default 'ios',
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

create index if not exists device_tokens_user_id_idx on public.device_tokens(user_id);

alter table public.device_tokens enable row level security;

-- Each user manages only their own device tokens.
drop policy if exists "device_tokens_select_own" on public.device_tokens;
create policy "device_tokens_select_own"
    on public.device_tokens for select
    using (auth.uid() = user_id);

drop policy if exists "device_tokens_insert_own" on public.device_tokens;
create policy "device_tokens_insert_own"
    on public.device_tokens for insert
    with check (auth.uid() = user_id);

drop policy if exists "device_tokens_update_own" on public.device_tokens;
create policy "device_tokens_update_own"
    on public.device_tokens for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

drop policy if exists "device_tokens_delete_own" on public.device_tokens;
create policy "device_tokens_delete_own"
    on public.device_tokens for delete
    using (auth.uid() = user_id);

-- Keep updated_at fresh on upsert/update.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists device_tokens_set_updated_at on public.device_tokens;
create trigger device_tokens_set_updated_at
    before update on public.device_tokens
    for each row execute function public.set_updated_at();
