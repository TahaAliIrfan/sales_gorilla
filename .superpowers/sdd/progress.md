# Odoo Partner Portal Connector — SDD Progress

Branch: feat/odoo-portal-connector
Base commit (docs): 6d4d4cf
Env: ruby 3.3.0 via `export PATH="$HOME/.rbenv/shims:$PATH"`
Note: spec/models/membership_spec.rb has 2 PRE-EXISTING failures on revamp (not ours).

## Tasks
- [x] Task 0: branch + node agent scaffold (commit a node-agent)
- [x] Task 1: complete (commit d8559ad, review clean: 2 examples 0 failures)
- [x] Task 2: complete (commit 73e60e0, review clean: 3 examples 0 failures; FIXED schema.rb regression that dropped 7 tables + rebuilt dev/test DBs from full schema)
- [x] Task 3: complete (commit ef87d2a, 2 examples 0 failures, schema clean)
- [x] Task 4: complete (commit 3060be5, 1 example 0 failures, schema clean)
- [x] Task 5: complete (commit bcd7150, 2 examples 0 failures)
- [x] Task 6: complete (commit 26ed91b, 3 examples 0 failures; live selector capture deferred — needs portal creds)
- [x] Task 7: complete (commit 4a5c23f, 1 example 0 failures)
- [x] Task 8: complete (commit 93a0628, 3 examples 0 failures; impl used find_or_create_by! idempotency; fixed plan test-3 double-stub bug)
- [x] Task 9: complete (commit 8cce8c3, 2 examples 0 failures)
- [x] Task 10: complete (commit 8d2a429, 2 examples 0 failures)
- [x] Task 11: complete (commit 95effdb, 5 examples 0 failures). FLAG for final review: subagent also made a minimal safe fix to Customer#record_activity_changes (skip activity log when no user exists; no prod behavior change) — needed for background customer updates.
- [x] Task 12: complete (commit 14e4253, 2 examples 0 failures)
- [x] Task 13: complete (commit 7b39ccb, 1 example 0 failures; backend connect/disconnect — view-card wiring into Relay features page is a follow-up)

## Environment notes (IMPORTANT for remaining tasks)
- Schema-driven repo: 7 tables (sms, google_meets, etc.) have NO migration files.
- Dev + test DBs now rebuilt complete (50 tables). `db:migrate` dumps cleanly now.
- ALWAYS verify after a migration task: `git show HEAD:db/schema.rb | grep -c create_table` must NOT drop below the prior count. If it does, restore from prior schema + re-run only the new migration against a schema:load'd DB.

## FINAL STATUS — COMPLETE (2026-06-23)
- All 14 tasks done. Full connector suite: 32 examples, 0 failures. Schema intact (51 tables). No co-author lines.
- Final whole-branch review (opus) found 1 CRITICAL + 3 IMPORTANT; all fixed in commit 38c87f9:
  - C1: lead_source is taxonomy-validated -> seed "Odoo Partner Portal" lead_source taxonomy on connect + per-lead RecordInvalid isolation.
  - I1: per-lead error isolation (bad lead -> mark_failed, batch + connection survive).
  - I2: admin-gated the manual /odoo_portal/sync endpoint (TenantController + Pundit).
  - I3: hardened push-worker rescue (hoisted conn).
- Branch feat/odoo-portal-connector (30+ commits off origin/revamp). NOT pushed/merged — awaiting user push + PR for Taha review.
- Known follow-ups (documented, out of scope): live-portal selector + write_action click-path capture (needs real portal creds; node agent currently stubs write_action -> add a verify-action-landed check then); wire the connect card into the Relay features page; per-org editable field/event maps.

## LIVE VALIDATION against real odoo.com partner portal (2026-06-23)
- READ path VALIDATED LIVE: agent's list_leads logic extracted all 16 real leads (correct portal_lead_id from /my/lead/<id>, contact_name, email, phone from list columns).
- PARSER rewritten for the REAL detail-page structure (schema.org microdata scoped to the "Customer:" row + name from the title; does NOT leak Tecaudex's own contact). 34 connector examples pass; fixture is a real captured page. Commit 1279175.
- WRITE-BACK mechanics VALIDATED (dry-run, no submit): both modal forms found + fillable on the live page:
    - exception/disqualify -> form.desinterested_partner_assign_form (comment + customer_mark_spam + .desinterested_partner_assign_confirm)
    - accept/note -> form.interested_partner_assign_form (comment + .interested_partner_assign_confirm); both carry csrf_token + lead_id.
- STILL UNVALIDATED: the actual write submit (clicking Confirm -> AJAX POST landing). Needs ONE real submit on a genuinely-junk lead with user go-ahead.
- PRODUCTION connect flow needs the user's httpOnly `session_id` cookie pasted into Settings (DevTools > Application > Cookies > odoo.com > session_id).

## Sub-project 3: Lead Intelligence (enrichment + call scripts) — IN PROGRESS
Plan: docs/superpowers/plans/2026-06-23-lead-intelligence.md (T1-T9)
- [x] T1 ai feature key (8474c67)  - [x] T2 Ai::Client (4af777c)  - [x] T3 customer columns (b58f53b)  - [x] T4 LeadEnrichmentService (5791e16)
- [x] T5 EnrichLeadWorker (ee5d9cd)  - [x] T6 CallScriptService (020a3c2)  - [x] T7 GenerateCallScriptWorker (903ab5e)
- [x] T8 auto-trigger (7d41990)  - [x] T9 customer UI (9814bc3) — LEAD INTELLIGENCE COMPLETE

## STATUS SUMMARY
- Sub-project 2 (Odoo connector): COMPLETE + live-validated against real portal (read path proven, write-back mechanics proven, email/password auto-reauth). 1 pending: real write-submit test on a junk lead.
- Sub-project 3 (Lead Intelligence): COMPLETE — 23 examples 0 failures (ai feature + Ai::Client + enrich service/worker + call-script service/worker + auto-trigger + customer UI).
- Sub-project 4 (Demo Builder): NEXT. "Build Demo" button -> classify industry (use enrichment.industry) -> seed branded Odoo DB on demo.tecaudex.pk -> images -> story PDF -> URL+login+PDF on the Customer. Needs: Rails side (DemoBuilderService + DemoServerClient (mockable) + BuildDemoWorker + customer demo_* columns + button) AND a server-side parameterized demo-builder on demo.tecaudex.pk.

## Sub-project 4: Demo Builder — IN PROGRESS (plan: docs/superpowers/plans/2026-06-23-demo-builder.md)
- [x] D1 demo_engine feature (a1b7229)  - [x] D2 customer demo columns (a0ae5e4)  - [x] D3 Demo::ServerClient (2fe35d7)
- [ ] D4 DemoBuilderService  - [ ] D5 BuildDemoWorker  - [ ] D6 DemoGuidePdfService+worker  - [ ] D7 button+UI
- [ ] SERVER: python demo-builder endpoint on demo.tecaudex.pk
