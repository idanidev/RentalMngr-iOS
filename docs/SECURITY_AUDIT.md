# RentalMngr — Security & Architecture Audit

Multi-agent adversarial audit (94 agents). **79 confirmed findings** — 10 High, 24 Medium,
33 Low, 12 Info. No secret leaked in tracked source (only the publishable **anon** key ships;
the APNs `.p8` is correctly gitignored).

## Executive summary
The client talks to Supabase directly with the anon key, so **RLS + Storage bucket privacy are
the ENTIRE isolation boundary for tenant PII** (DNI/passport, phone, email, address, financials,
ID scans, contracts). Those policies are **not committed** and cannot be proven from source — so
the biggest risk lives in the live Supabase project, not the app code. Overall posture:
**MEDIUM-HIGH, dominated by unverifiable server config.** If RLS + bucket privacy are correct,
residual client risk is medium.

---

## ✅ Fixed in code (this pass)
| Fix | Finding |
|---|---|
| Catalyst auth session moved from **plaintext UserDefaults → Keychain** (`SecItem`, `AfterFirstUnlockThisDeviceOnly`) | HIGH AUTH-001/1.1 |
| App lock now **gates the whole authenticated tree** (MainTabView not built / no fetch / no realtime while locked) + locks on **cold launch** | MED AUTH-002 / LOCK-001 |
| Push token **revoked on sign-out** (`clearOnSignOut` wired into `signOut`) | MED 2.5 |
| `send-push` hardened: requires `x-webhook-secret`, validates UUID, **no longer returns device tokens**, no `data` root-spread, generic 500 | MED PUSH-001..004 |
| `GlobalFinanceViewModel` realtime **debounced (400ms) + in-flight guard** (stops request storm) | HIGH 6.1 |
| Data race on `scheduleRefresh` fixed → `@MainActor` (PropertyDetail + FinanceSummary VMs) | MED 4.1 |
| `LocalNotificationScheduler` N+1 reduced — vacant count from **embedded rooms**, dropped per-property rooms fetch | MED 6.3 |
| Contract + Room-ad PDFs **deleted from temp on disappear** (PII no longer left in temp) | MED 2.6 (partial) |
| `income`/`utility_charges` `month` decode **throws instead of defaulting to today** (no financial mis-bucketing) | LOW 5.2 |
| AnnualReport shares only on successful write; entitlement `print` behind `#if DEBUG` | 5.5 / info |

Deliverables (your action): `supabase/SECURITY_HARDENING.sql` (RLS + storage template),
hardened `supabase/functions/send-push/index.ts`.

---

## ⚠️ MUST VERIFY / FIX IN SUPABASE (client code cannot prove these)
1. **Enable RLS + correct policies on EVERY PII table**: `tenants, properties, rooms, income,
   utility_charges, shared_expenses, documents, invitations, property_access, property_utilities`.
   Only 6 minor tables have committed RLS; the PII tables have **none in source** and the client
   does zero defense-in-depth (queries carry no owner filter). One gap = full cross-tenant PII leak.
   → adapt & run `supabase/SECURITY_HARDENING.sql`, then commit as migrations.
2. **Write-time role enforcement**: `canEdit` is UI-only. Confirm UPDATE/DELETE RLS checks the
   caller's role in `property_access` (`role in ('owner','editor')`), else a viewer can edit/delete.
3. **Make `documents` + `room-photos` buckets PRIVATE** and switch to **signed URLs**. Today every
   file (scanned IDs, signed contracts) is a permanent public URL. Add `storage.objects` RLS.
4. **`send-push`**: set `PUSH_WEBHOOK_SECRET`, configure the Database Webhook to send the
   `x-webhook-secret` header, and deploy **without `--no-verify-jwt`**.
5. **Cross-account RPCs** — audit & commit their bodies: `get_user_by_email` (enumeration oracle →
   return minimal id/bool + rate-limit), `grant/remove_property_access` (verify caller owns the
   property), `delete_account` (must cascade all PII **and delete Storage objects**).
6. **`apply_premium_purchase`** — client-supplied expiry, no receipt check = free premium. Validate
   the StoreKit transaction server-side (App Store Server API) and revoke client EXECUTE.

## Top 5 (security-weighted)
1. RLS on all PII tables · 2. Private buckets + signed URLs · 3. Lock down `send-push` ·
4. (done) Catalyst tokens off UserDefaults · 5. Account deletion erases Storage + gate premium.

---

## Remaining code items (not yet done — mostly Low / architectural)
- PDF temp cleanup for **ContractPreview + AnnualReport** views; drop tenant name from PDF filename/share title.
- `try?`-swallowed errors in **ExpenseListView / NotificationSettingsView / SearchView** (need error-UI plumbing).
- Tenant name in contract-expiry **notification body** (2.7) — kept as-is (landlord's own device; useful).
- **Architecture**: inject `SupabaseClient` into services (currently bound to `SupabaseService.shared`,
  untestable); split `AppState` god-object; extract a post-login bootstrap coordinator (fetches properties twice).
- **Privacy/GDPR**: in-app privacy policy + consent; data-retention/purge job; `delete_account` Storage erasure
  (Edge Function); DNI purpose statement / at-rest encryption.
- Dead code: `NavigationConceptView` (586 LOC) + mockup screens → `#if DEBUG` / delete.
- `SupabaseConfig` xcconfig plumbing is dead (hardcoded fallback always used) — wire it or accept it.

_Full per-finding detail with file:line lives in the audit run output; this file is the actionable digest._
