# Odoo Partner Portal Connector

**Status:** Proposed — design approved, awaiting implementation plan
**Owner:** Arham (design) · Taha (architecture review)
**Last updated:** 2026-06-19
**Depends on:** [Modular ERP Architecture Plan](./modular-erp-plan.md)

## Goal

Let **any Odoo partner organisation** automatically sync the leads assigned to
them in the **odoo.com partner portal** ("DU Partnership" / registration &
download leads) into their CRM as `Customer` records, and push status updates
**back** into the portal — all without an API, because the partner portal does
not expose one.

This ships as a new module in the existing modular-ERP pattern: a per-org
`OrganizationFeature` toggle + provider, a Rails Engine for the connector, and
provider-specific work isolated behind an adapter. It mirrors the existing
self-service inbound pattern (`MetaInboundLead` / `ProcessMetaInboundLeadWorker`
/ `MetaPageConnection`).

## Why not an API

The odoo.com partner portal is Odoo's own hosted instance. Partners get a
limited **web UI only** — no XML-RPC/JSON-RPC access to those leads. The
authoritative source is the portal screen itself. Therefore the connector reads
(and writes) the portal through an automated **headless browser** (Puppeteer,
already in the stack) driving a **saved, authenticated session**.

> A separate connector (not this doc) covers BYO customer Odoo instances, which
> *do* have a JSON-RPC API and get true API sync.

## Scope

**v1 (this spec) — two-way:**
1. **Ingest:** portal leads → `Customer` (email-triggered + scheduled + manual).
2. **Write-back:** CRM events → portal actions (mark "Exception", log a note,
   move stage) through the same session.
3. **Multi-tenant & self-service:** any org connects its own portal session.

**Out of scope (future):** BYO Odoo JSON-RPC connector; bulk historical
backfill beyond what the portal list shows; portal analytics.

## Decisions (locked)

| Decision | Choice |
|---|---|
| Source of truth | The partner portal UI (no API) |
| Automation | Headless browser (Puppeteer) with a **saved session** |
| Login | **Never automated.** One-time interactive connect captures session cookies; reused thereafter. Handles password *and* "Sign in with Google" + 2FA uniformly. |
| Feature scope | Per organisation (`OrganizationFeature` key `odoo_partner_portal`) |
| Credentials/session at rest | Rails 7 `encrypts` on the connection record |
| Primary trigger | **Inbound lead-notification email** signals a fetch |
| Backstop trigger | Scheduled poll (`sidekiq-scheduler`) + manual "Sync now" |
| Direction | Two-way (ingest + write-back) in v1 |

## Architecture

Follows the three-layer shape from the modular-ERP plan: host app holds the
feature flag + tenancy; an engine holds the connector; an adapter holds the
portal-specific browser work.

```
Host app
  ├─ OrganizationFeature(:odoo_partner_portal)   ← toggle + provider
  ├─ Settings::FeaturesController                ← connect / re-auth UI
  └─ Customer (upsert target)
        │ mounts /odoo_portal
        ▼
OdooPortal Engine (engines/odoo_portal)
  ├─ Models: OdooPortalConnection, PartnerPortalLead
  ├─ Workers: OdooPortalSyncWorker, OdooPortalPushWorker
  ├─ Services: OdooPortal::Session, OdooPortal::Scraper, OdooPortal::Writer
  └─ Email detector hook (into GmailInboxSyncWorker)
        │ delegates browser work
        ▼
Browser session (Puppeteer + stored cookies, per org)
```

## Components

| Component | Responsibility | Mirrors |
|---|---|---|
| `OrganizationFeature(:odoo_partner_portal)` | on/off + provider `odoo` + settings (notify match rules) | `meta_lead_ads` |
| `OdooPortalConnection` | per-org encrypted **session cookies** + status (`active` / `needs_reauth`) + `last_synced_at` + watch-mailbox ref | `MetaPageConnection` |
| `PartnerPortalLead` | one sync row per portal lead: `portal_lead_id` (unique per org), `status` (received/processed/failed/duplicate), raw scraped payload, linked `customer` | `MetaInboundLead` |
| `OdooPortal::Session` | load/validate the saved session; raise `NeedsReauth` when expired | — |
| `OdooPortal::Scraper` | navigate the Leads/Opportunities list, diff against known `portal_lead_id`s, open each new lead, extract fields | — |
| `OdooPortal::Writer` | perform a write-back action (note / Exception / stage) on a given portal lead | — |
| `OdooPortalSyncWorker` | orchestrate a fetch: session → scraper → `PartnerPortalLead` rows → `Customer` upsert | `ProcessMetaInboundLeadWorker` |
| `OdooPortalPushWorker` | enqueued by Customer/Deal callbacks → `Writer` performs the portal action | — |
| Email detector | in the existing 5-min Gmail sync, match Odoo lead emails → enqueue `OdooPortalSyncWorker` | extends `GmailInboxSyncWorker` |
| Settings UI | connect (capture session), show health, re-auth, "Sync now", field/event mapping | `/settings/features` |

## Data flow — ingest

1. **Trigger** (any of): a matching lead-notification email arrives (primary);
   the scheduled poll fires; or an admin clicks "Sync now".
2. `OdooPortalSyncWorker` loads the org's saved session via `OdooPortal::Session`.
   If invalid → mark connection `needs_reauth`, alert admin, stop.
3. `OdooPortal::Scraper` opens the portal Leads/Opportunities list and diffs the
   visible lead ids against existing `PartnerPortalLead.portal_lead_id`s for the
   org. New ones only.
4. For each new lead: open it, extract fields, create a `PartnerPortalLead`
   (`received`), then **upsert** a `Customer` and `mark_processed!`.
5. Raw scraped payload is retained on the row so nothing is lost if a field
   isn't mapped.

**Field map (portal → `Customer`):** customer name → `name`; company →
`company`; phone → `phone` (+ `country_code`); email → `email`; address/city →
`address`; sales team → `notes`/tag; stage/status → `status`;
`lead_source = "Odoo Partner Portal"`; portal lead id → `portal_lead_id`.

## Data flow — write-back

1. Rails `after_update` on `Customer`/`Deal` enqueues `OdooPortalPushWorker`
   when a mapped event occurs.
2. **Event map (CRM → portal action):** e.g. Customer disqualified → portal
   **"Exception"** (with reason note); status change → **log a note**; deal
   stage change → **move portal stage** where the portal allows it.
3. `OdooPortal::Writer` opens the lead via the saved session and performs the
   click-path.
4. **Loop prevention:** record `portal_last_pushed_at` / a content checksum on
   the `Customer`. An inbound scrape that only reflects our own just-written
   change is detected and skipped (no echo Customer update).

## Trigger model

- **Email-signalled (primary):** the org connects the mailbox that receives DU
  lead emails; the existing per-user Gmail sync (every 5 min) runs a detector
  that matches the Odoo lead email (configurable from/subject rules) and
  enqueues a fetch. The email is only a *signal* — full detail comes from the
  scrape — so it works even if the email lacks lead fields.
- **Scheduled poll (backstop):** `sidekiq-scheduler` entry runs a fetch every
  few hours per active connection, catching missed emails.
- **Manual:** "Sync now" button in settings.

## Multi-tenancy & self-service

- Everything is per `Organization` (`acts_as_tenant`), exactly like Meta inbound.
- Each org connects **its own** portal session and watch-mailbox; nothing is
  Tecaudex-specific.
- The scraper targets the common odoo.com partner-portal UI, so one
  implementation serves every partner.

## Error handling

- **Session expiry** → connection `needs_reauth` + admin alert; fetches/pushes
  pause until re-connected (mirrors Meta token-expiry handling).
- **Scrape/selector failure** → retry with backoff; mark the `PartnerPortalLead`
  `failed` with the error; alert via the existing `ServerHealthMonitor` channel.
- **Portal UI drift** → resilient selectors + a canary check that flags layout
  changes early.
- **Duplicates** → idempotent on `portal_lead_id`.
- **Partial writes (write-back)** → the push worker is retryable and verifies
  the action landed before marking success.

## Security & compliance

- Session cookies and any credentials are **encrypted at rest** (Rails 7
  `encrypts`), same as other provider settings.
- Only an org's own admins can connect/disconnect.
- The connector reads/writes **the partner's own authorised portal data** on
  their behalf; document this in the connect flow.

## Open questions (for implementation plan)

1. Where does the one-time interactive login happen — an embedded remote browser
   in the connect flow, or an admin-run local capture uploaded once?
2. Exact portal selectors / lead-detail layout (capture during build).
3. Which CRM events map to which portal write-back actions (default map + UI to
   edit, mirroring the Meta status→event mapping).
4. Rate/concurrency limits for browser sessions per worker host.
