# Per-Organization User Management & RBAC

Status: **Phase 1 + Phase 2 implemented** (on `revamp`, verified on a fresh dev DB).
Supersedes the global `Role`/`RoleAssignment` hierarchy with a per-organization
role+permission model. Companion to [`modular-erp-plan.md`](./modular-erp-plan.md).

Implemented:
- **Phase 1 (capability):** `20260608120000` — org-scoped `roles` (+ `permissions`
  jsonb, `system`), `memberships.role_id`, 5 system roles per org, `Permission`
  catalog, `Membership#can?` / `UserContext#can?`.
- **Phase 2 (visibility):** `20260608130000` adds `memberships.reports_to_id` (the
  per-org manager hierarchy) and backfills it from the old assigned_by chains;
  `20260608140000` drops `role_assignments` and the legacy global roles. `User`'s
  `admin?` / `manager?` / `associates` / `highest_role` now resolve against the
  active tenant's membership (fallback: "in any org" when no tenant). API/`case`
  call sites use `User#legacy_role_key` for the old `admin/manager/associate` vocab.
  User-management screens (`users#index/show/associates/managers/manage_associates`,
  Settings → Team) operate on memberships.
- **Roles & Permissions UI:** per-org `RolesController` + `resources :roles` —
  list/show/create/edit/delete org roles, edit each role's granted permissions via
  checkboxes grouped by `Permission::CATALOG`. System roles lock name/key/rank
  (permissions still editable); owner always retains all permissions
  (`Role#owner_keeps_all_permissions`); custom roles are fully editable and
  assignable to users. Gated on `can?("roles.manage")`.

---

## 1. Why

Today there are **two parallel role systems** that fight each other:

| System | Table | Vocabulary | Scope | Drives |
|---|---|---|---|---|
| Global CRM hierarchy | `roles` + `role_assignments` | `admin` / `manager` / `associate` (+ `hierarchy_level`, `assigned_by_id`) | **CRM-wide, not org-scoped** | `user.admin?`, `user.manager?`, `user.associates`, `can_access_customers_for?`, `accessible_deals` |
| Per-org membership | `memberships` | `owner` / `admin` / `member` / `viewer` | per-organization | `UserContext#org_admin?`, `can_administer?`, branding access |

The problem: the **capability + manager→associate hierarchy is global**, so the same
person cannot be a manager in Org A and a member in Org B, and the
manager-sees-associates visibility rollup ignores org boundaries entirely. We have a
per-org *membership* but the actual authorization still runs off the global system.
`user.admin?` / `user.manager?` are referenced in **~277 call sites** across
controllers, policies, and views.

## 2. How the reference platforms do it

All three converge on **two orthogonal axes**, always **inside a tenant**:

- **Capability — "what you can do."** A reusable, additive *bundle of permissions*
  attached to a user. Salesforce = Profile + Permission Sets; HubSpot = Roles
  (formerly Permission Sets, ≤100 per account); Odoo = Groups + ACL (union of all a
  user's groups).
- **Visibility — "which records you see."** Driven *separately* by an org-chart
  hierarchy + lateral sharing. Salesforce = Role Hierarchy + Sharing Rules over
  Org-Wide Defaults; HubSpot = Teams (hierarchical, primary/secondary); Odoo = Record
  Rules (`ir.rule` domain filters, e.g. "own records", "own company").
- **Tenancy.** Salesforce = separate org instance; HubSpot = separate account; Odoo =
  multi-company record scoping. Ours = `acts_as_tenant(:organization)` (already the
  equivalent of Odoo record rules / company scoping).

Takeaway for us: keep capability (a per-org **Role** = bundle of **permissions**)
separate from visibility (a per-org **hierarchy**), and scope both to the
organization. This is what "mimic HubSpot/Salesforce/Odoo per organization" means.

## 3. Target model

```
User ──< Membership >── Organization          (already exists; the per-org identity)
              │
              ├─ role_id ─────► Role           (org-scoped capability bundle; Phase 1)
              │                   └─ permissions: jsonb[]  (grants, from code catalog)
              │
              └─ reports_to_id ─► Membership    (per-org manager hierarchy; Phase 2)
```

- **Membership** stays the unit of belonging (Salesforce "User" / HubSpot seat-holder).
  Gains `role_id` (capability) in Phase 1 and `reports_to_id` (visibility) in Phase 2.
- **Role** becomes **org-scoped** (`organization_id`) with a `system` flag. Each org is
  seeded with the 5 system roles below; custom roles (HubSpot-style, ≤N per org) can be
  added later. A role's grants are a `jsonb` array of permission keys.
- **Permission catalog** lives in **code** (`Permission` module) — a fixed list of
  capability keys grouped by category, à la Odoo ACL / Salesforce permission. We store
  *grants* as a `jsonb` array on the role (no `permissions`/`role_permissions` tables —
  deliberately narrow; revisit only if we need to query "who has permission X").

### Unified role vocabulary (collapses both systems)

| key | level | replaces | org.administer | data scope (Phase 2) |
|---|---|---|---|---|
| `owner` | 100 | global `admin` + membership `owner` | ✔ (+ billing, delete org) | all |
| `admin` | 90 | membership `admin` | ✔ | all |
| `manager` | 50 | global `manager` | — (manage users only) | own + direct reports |
| `member` | 10 | global `associate` + membership `member` | — | own |
| `viewer` | 0 | membership `viewer` | — | read-only |

`associate` → `member` is the one user-facing rename.

### Permission catalog (initial)

Grouped keys, e.g.: `org.administer`, `org.manage_billing`, `org.delete`,
`users.view`, `users.manage`, `users.invite`, `roles.manage`,
`customers.view_all` / `.view_team` / `.view_own`, `customers.export`,
`customers.bulk_edit`, `deals.view_all` / `.assign`, `recordings.view_all`,
`settings.manage`, `templates.manage`. Final list derived by auditing the ~277 call
sites. Each system role ships with sensible default grants; custom roles pick from the
catalog in the admin UI.

## 4. Phase 1 — Capability (this change)

**Additive and non-breaking. Does NOT flip the 277 call sites yet.**

### Schema

```ruby
# roles: make org-scoped, add grants + system flag
add_reference :roles, :organization, foreign_key: true, index: true  # nullable: NULL = legacy/global template
add_column    :roles, :permissions, :jsonb, null: false, default: []
add_column    :roles, :system, :boolean, null: false, default: false
remove_index  :roles, :key                                            # was globally unique
add_index     :roles, [:organization_id, :key], unique: true

# memberships: point at a capability role
add_reference :memberships, :role, foreign_key: { to_table: :roles }, index: true  # nullable during transition
```

The legacy global rows (`organization_id IS NULL`, keys `admin`/`manager`/`associate`)
stay put and keep backing `role_assignments` untouched, so existing `associates`
behavior is unchanged in Phase 1. `Role.admin/manager/associate` class methods scope to
`where(organization_id: nil)`.

### Backfill (critical detail)

`membership.role_id` must be derived from the user's **global `RoleAssignment`**, NOT
from the existing `memberships.role` string — that string conflated org-ownership with
capability (the original backfill made *every* non-admin an org `admin`). Per user, per
org:

```
global admin    → owner
global manager  → manager
global associate→ member
no global role  → member
```

This reproduces today's authorization exactly (only former global admins get
`org.administer`).

### Model layer

- `Permission` module — catalog + per-system-role defaults.
- `Role` — `belongs_to :organization, optional: true`; `grants?(key)`; `system`/custom
  scopes; `Role.seed_system_roles!(org)`.
- `Membership` — `belongs_to :role, optional: true`; `can?(key)`; predicates read the
  role record.
- `UserContext#can?(key)` — `membership&.role&.grants?(key)` with a global-admin override.
- New code authorizes via `can?(:permission)`; legacy `admin?`/`manager?` untouched.

## 5. Phase 2 — Visibility (next change)

- Add `memberships.reports_to_id` (self-ref) — the per-org manager hierarchy (Salesforce
  Role Hierarchy / HubSpot Teams). Optionally an org-scoped `Team` model later.
- Move `user.associates` / `can_access_customers_for?` / Pundit scopes off
  `RoleAssignment.assigned_by` onto `membership.reports_to`, scoped to the current org.
- Re-point `user.admin?` / `user.manager?` shims to be **tenant-aware** (resolve the
  current tenant's membership; fall back to legacy when no tenant, e.g. background jobs).
  Because prod is effectively single-org (Tecaudex), this is behavior-preserving today
  while becoming correct for multi-org.
- Once all call sites read membership, **drop `role_assignments`** and the legacy global
  rows in a final cleanup migration.

## 6. ⚠️ Environment blocker — must resolve before any migration runs

The `revamp` dev DB is **inconsistent** with `schema.rb`:

- `schema_migrations` records `20260604180000` (create orgs+memberships) and the
  org-feature migrations as **run**, but `organizations`, `memberships`, and
  `organization_features` **do not exist** in the DB (dropped manually per the
  2026-06-06 incident; ledger never reverted, `schema.rb` never regenerated).
- `20260607012000_add_devise_to_users` is genuinely pending (dev DB likely lacks
  `encrypted_password`).
- `rails db:migrate` will therefore only add Devise columns — it will **not** recreate
  the org tables (marked done) — leaving the DB half-broken.

**This must be reconciled before the Phase 1 migration can run or be tested.** Options:

1. **Re-create the multi-org schema in dev only** — delete the three stale
   `schema_migrations` rows, then `db:migrate` to re-run org + devise + Phase 1. Dev-only;
   prod untouched.
2. **`db:schema:load` into a fresh dev DB** from current `schema.rb`, then run Phase 1.
   Cleanest if dev data is disposable.
3. Investigate why the ledger/tables drifted before touching anything.

## 7. Prod safety

- Prod (`master`) is currently **org-free** and must stay that way until a deliberate,
  separately-planned cutover (it broke live before — Zapier 500s). All Phase 1/2 work
  lands on `revamp`; **no migration here assumes the org tables exist in prod.**
- Every migration must be reversible (`up`/`down`) and backfills idempotent.
