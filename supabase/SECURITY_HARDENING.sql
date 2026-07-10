-- ============================================================================
-- RentalMngr — SECURITY HARDENING (RLS + Storage)  [from the security audit]
--
-- The iOS client talks to Supabase directly with the ANON key, so RLS + Storage
-- bucket privacy are the ENTIRE isolation boundary for tenant PII (DNI, phone,
-- email, address, financials, ID scans, contracts).
--
-- ⚠️ This is a TEMPLATE. VERIFY every table/column name against your real schema
--    before running, and run it on a STAGING project first. Wrong RLS can lock the
--    app out or leave a hole. Ownership model assumed: public.property_access(user_id,
--    property_id, role) where role ∈ ('owner','editor','viewer'), and most PII tables
--    carry a property_id. Adapt if yours differs.
-- ============================================================================

-- ---- 0. Ownership helper functions ----------------------------------------
create or replace function public.has_property_access(p_property_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.property_access pa
    where pa.property_id = p_property_id and pa.user_id = auth.uid()
  );
$$;

create or replace function public.can_edit_property(p_property_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.property_access pa
    where pa.property_id = p_property_id and pa.user_id = auth.uid()
      and pa.role in ('owner','editor')
  );
$$;

create or replace function public.owns_property(p_property_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.property_access pa
    where pa.property_id = p_property_id and pa.user_id = auth.uid() and pa.role = 'owner'
  );
$$;

-- ---- 1. PROPERTIES ---------------------------------------------------------
alter table public.properties enable row level security;
drop policy if exists properties_select on public.properties;
create policy properties_select on public.properties for select
  using (public.has_property_access(id));
drop policy if exists properties_update on public.properties;
create policy properties_update on public.properties for update
  using (public.can_edit_property(id)) with check (public.can_edit_property(id));
drop policy if exists properties_delete on public.properties;
create policy properties_delete on public.properties for delete
  using (public.owns_property(id));
-- INSERT: adapt to how a new property + its owner property_access row are created
-- (e.g. via a SECURITY DEFINER RPC). If inserted directly, gate on owner_id = auth.uid().

-- ---- 2. Property-scoped PII tables -----------------------------------------
-- Same pattern for each: read if you can access the property, write if you can edit it.
do $$
declare t text;
begin
  foreach t in array array[
    'rooms','tenants','income','utility_charges','shared_expenses','property_utilities','documents'
  ] loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('drop policy if exists %I on public.%I;', t||'_select', t);
    execute format('create policy %I on public.%I for select using (public.has_property_access(property_id));', t||'_select', t);
    execute format('drop policy if exists %I on public.%I;', t||'_write', t);
    execute format('create policy %I on public.%I for all using (public.can_edit_property(property_id)) with check (public.can_edit_property(property_id));', t||'_write', t);
  end loop;
end $$;
-- NOTE: if `documents` is keyed by tenant_id (not property_id), replace property_id with
-- a join to the tenant's property. Verify the column exists on each table above.

-- ---- 3. property_access (who can see/manage collaborators) ------------------
alter table public.property_access enable row level security;
drop policy if exists pa_select on public.property_access;
create policy pa_select on public.property_access for select
  using (user_id = auth.uid() or public.owns_property(property_id));
drop policy if exists pa_write on public.property_access;
create policy pa_write on public.property_access for all
  using (public.owns_property(property_id)) with check (public.owns_property(property_id));

-- ---- 4. invitations --------------------------------------------------------
alter table public.invitations enable row level security;
drop policy if exists inv_owner on public.invitations;
create policy inv_owner on public.invitations for all
  using (public.owns_property(property_id)) with check (public.owns_property(property_id));
-- Plus a SELECT policy so an invitee can see invitations addressed to their email:
drop policy if exists inv_invitee_select on public.invitations;
create policy inv_invitee_select on public.invitations for select
  using (lower(email) = lower((auth.jwt() ->> 'email')));

-- ---- 5. Storage objects (documents + room-photos must be PRIVATE) ----------
-- FIRST, in the dashboard (or via API), set both buckets to PUBLIC = false.
-- Then scope object access to property ownership. NOTE: room-photos paths use the
-- ROOM id as the leading folder in this app; documents use property/tenant. Adjust
-- the split_part(...) index to match your real key layout, then verify.
do $$ begin
  drop policy if exists documents_objects_rw on storage.objects;
  create policy documents_objects_rw on storage.objects for all
    using (
      bucket_id = 'documents'
      and public.has_property_access( (split_part(name,'/',1))::uuid )
    )
    with check (
      bucket_id = 'documents'
      and public.can_edit_property( (split_part(name,'/',1))::uuid )
    );
exception when others then raise notice 'Adapt documents storage policy to your key layout: %', sqlerrm; end $$;

-- ---- 6. apply_premium_purchase — stop trusting the client expiry -----------
-- The current RPC writes tier='premium' with a CLIENT-SUPPLIED p_expires_at and no
-- receipt validation → free premium. Until you move validation into a service_role
-- Edge Function (App Store Server API), at minimum REVOKE client execute:
-- revoke execute on function public.apply_premium_purchase(timestamptz) from authenticated;
-- (adjust the signature to match yours), then gate real upgrades server-side.

-- ---- 7. Cross-account RPCs to audit & commit -------------------------------
-- Confirm these run SECURITY DEFINER and verify the CALLER's authority server-side,
-- then commit their bodies as migrations (they are currently only in the live DB):
--   * get_user_by_email        → return minimal id/bool only; rate-limit (enumeration oracle)
--   * grant_property_access    → verify caller owns the target property
--   * remove_property_access   → verify caller owns the target property
--   * delete_account           → cascade ALL pii tables AND delete Storage objects
