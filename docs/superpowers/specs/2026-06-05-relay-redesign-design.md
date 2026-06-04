# Relay redesign — design spec

**Date:** 2026-06-05 · **Branch:** `revamp` · **Status:** approved approach (Hotwire-native), phased implementation

## Goal

Implement the **Relay** design (Claude Design handoff bundle) as the new frontend of the Tecaudex CRM: a white-label, multi-tenant, multi-channel sales CRM with a dark-sidebar + light-console layout, consolidated into 6 primary workspaces. The full design intent lives in the bundles preserved at:

- `docs/design/relay-app/` — the app design (read `README.md`, `chats/chat1.md`, `project/Relay.html` + `project/app/*.jsx`, `project/Invoice.html`, screenshots)
- `docs/design/relay-ds/` — the Relay Design System (tokens, component CSS, galleries, fonts, assets)

The prototypes are **React/JSX mockups**; per the design README they are visual specs to be recreated pixel-faithfully in the target stack — not code to port structurally.

## Approach (decided)

**Hotwire-native rebuild.** ERB views + Turbo Frames/Streams + Stimulus controllers on top of the **existing** controllers, models, policies, and jobs. No JSON-API conversion, no JS build system, no React. Rationale: it's the Rails convention for data-dense CRUD dashboards, every hard interaction (kanban DnD, palette, chat, dialer) has an established Hotwire pattern, and the backend already works. (Researched 2026-06; e.g. railsdesigner.com kanban-with-Hotwire, Hotwire production-patterns guides.)

## Information architecture

New tenant-area nav (sidebar): **Today · Leads · Inbox · Pipeline · Outreach · Insights** + **Quotes & invoices** (Money group) + **Settings** (System group). All map to existing resources:

| Destination | Route | Backed by (existing) |
|---|---|---|
| Today | `/` tenant root | `user_dashboard`, `my_tasks_dashboard`, `customer_followups`, `manager#dashboard` (manager/admin layer) |
| Leads | `/customers` | `customers#index`, bulk assign/status/export, `csv_imports` (upload → column-map → import), assign-to-me |
| Lead workspace | `/customers/:id` | unified conversation: `messages` (WhatsApp) + `emails` + `recordings`/`ai_analyses`; context rail: AI phone analysis, timezone/best-time, documents, deals, tasks; money actions as drawers: `invoices`, `milestones`, `cost_estimates`, `odoo_proposals` |
| Inbox | `/inbox` (new controller, read-only aggregation) | conversation list across leads (pattern exists in `whatsapp_us#conversations`) |
| Pipeline | `/deals` | deals + `pipelines` + `deal_stages`; SortableJS kanban → `deals#update_stage`; deal drawer: audit trail, linked recordings, assign, won/lost; stage config |
| Outreach | `/outreach` (tabs) | `customer_groups`, `campaigns` (send/schedule/stop/restart, per-recipient status), `whatsapp_templates` |
| Insights | `/reports` | `reports#index` / `my_reports`, role-scoped via Pundit |
| Quotes & invoices | `/billing` (tabs) | `all_invoices`, `cost_estimates`, `odoo_proposals` |
| Settings | `/settings` (tabs) | settings/profile, `users` + roles + manager↔associate assignments, `branding` (live preview), integrations (Google), notifications prefs |

Rules:

- **Old routes keep working throughout the migration.** Each phase swaps views/partials for a page; endpoints are unchanged. New routes (`/inbox`, `/outreach`, `/billing`) are additive.
- Notifications render as a topbar panel (unread states, mark-all-read) — existing `notifications` controller.
- Global chrome: ⌘K command palette, topbar "New" quick-add menu, floating active-call bar (Twilio), DS toasts fed by Rails flash + Turbo Streams.
- Public invoice page `/i/:token` (`public_invoices`) restyled per `project/Invoice.html`, inheriting tenant branding.

## Design system port

- Copy verbatim from `docs/design/relay-ds/project/`: `fonts/fonts.css`, `colors_and_type.css`, `tokens.css`, `components.css`, `components-data.css`, `components-nav.css` → `app/assets/stylesheets/relay/`. These are framework-agnostic plain CSS (`rl-` prefixed classes, `--*` custom properties). **Never invent token names** — use only tokens defined there.
- New layout `app/views/layouts/relay.html.erb`: dark sidebar (264px, collapsible to 64px) + sticky 60px topbar + light scrolling console. Migrated pages opt in; legacy pages keep the old layout + Tailwind until final cleanup.
- **White-label brand engine**: port `ds.js#applyBrand()` (lightness curve × chroma multiplier per stop, oklch) to a Ruby helper that renders the 11 `--brand-*` stops as inline CSS in the layout head from `Organization`'s brand color. Server-rendered — no flash of default brand. Product name + logo per tenant from `Organization`/branding settings.
- **Icons**: Lucide, vendored as inline SVGs through an `icon(name, size:)` view helper (1.5px stroke, currentColor). No CDN. LinkedIn needs a hand-vendored SVG (dropped from Lucide).
- **Fonts**: Bricolage Grotesque (display), Hanken Grotesk (UI), JetBrains Mono (mono) via `fonts.css` (Google Fonts import) — acceptable; can self-host later.
- Light mode first. Dark mode is a `data-theme="dark"` token flip — deferred, not in scope.
- Content voice per the DS guide: sentence case, verb-first buttons, tabular figures, mono for IDs/phones/times, no emoji in chrome.

## Interactivity (Stimulus + Turbo)

Stimulus controllers (new): `dropdown`, `modal`, `drawer`, `toast`, `tabs`, `command-palette` (⌘K, arrow-key nav), `kanban` (SortableJS + request.js, optimistic move + Turbo Stream confirm), `chat-composer`, `bulk-select` (header checkbox + bulk bar), `sidebar` (collapse), `dialer` (wraps the existing Twilio Device JS; renders the floating call bar: mute/hold/keypad/record/end).

Turbo usage: Frames for drawers, tabs, and lazy panes (conversation pane, report charts — with DS skeletons as frame placeholders); Streams for real-time WhatsApp messages (existing job pipeline), kanban stage moves, campaign per-recipient status, and toast delivery.

States: server-rendered DS empty states; DS error pages (404/500/permission); flash → toast. Role-scoping uses real Pundit policies (admin/manager/associate) — **the prototype's Tweaks panel (brand/theme/role/state switcher) is demo chrome and is not implemented.**

Charts (Insights/Today): custom inline-SVG partials replicating the prototype's charts (bars, funnel, sparklines). No charting library.

## Phasing

Each phase is its own plan → implement → review cycle (writing-plans skill per phase). Order:

1. **Foundation** — DS CSS port, `relay` layout, shell (sidebar/nav/topbar/notifications panel), brand-ramp helper + tenant theming, icon helper, Stimulus primitives (dropdown/modal/drawer/toast/tabs/command-palette), flash-as-toast
2. **Today** — rep cockpit (KPIs, follow-ups overdue/today/upcoming with quick-complete, queue, assign-to-me, pipeline snapshot) + manager/admin team layer
3. **Leads** — dense filterable/sortable table, status pills, lead score, channel pips, bulk bar, CSV import flow
4. **Lead workspace** — unified conversation (calls + WhatsApp incl. templates/media + email compose/reply + recordings/transcripts/AI summaries + timeline), context rail, money-action drawers. Largest phase; may split conversation/rail/money internally.
5. **Pipeline** — kanban + deal drawer + won/lost + stage config
6. **Inbox** — cross-lead conversation triage (new controller)
7. **Outreach** — groups, campaigns (schedule, per-recipient status, stop/restart), templates
8. **Insights** — KPI dashboard, funnel, per-rep performance vs targets, date-range filter, role-scoped
9. **Billing** — quotes & invoices workspace + public invoice page restyle
10. **Settings/Admin** — profile, team & roles, integrations, branding screen with live preview; **final cleanup**: remove Tailwind, old layout, dead views

Phase exit criteria: page(s) render pixel-faithful to bundle screenshots with real data, old functionality preserved, `bin/dev` clean (no console errors), visual check against `docs/design/relay-app/project/screenshots/`.

## Error handling & verification

- Server errors keep existing flows; DS inline alerts/error states replace bare flash text on migrated pages.
- No test framework exists in the repo (per CLAUDE.md); verification is running the app and visually comparing against the design screenshots per phase. If a test framework is introduced later, system tests for the Stimulus-heavy pieces (kanban, palette) are the first candidates.

## Out of scope

- Dark mode (token flip, later)
- Tweaks panel from prototype (demo chrome)
- React/JS build system changes
- Backend/schema changes except: additive routes/controllers for Inbox/Outreach/Billing aggregation pages, and a brand-color field on Organization **only if** branding doesn't already store one
- Mobile/responsive beyond what the DS provides (desktop console product)
