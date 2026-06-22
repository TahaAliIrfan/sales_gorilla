# Lead Intelligence (enrichment + call scripts) — Implementation Plan

> Same TDD + subagent execution as the Odoo connector. Branch: feat/odoo-portal-connector. Env: `export PATH="$HOME/.rbenv/shims:$PATH"`. NO co-author lines in commits. `:sidekiq_fake` tag enables `Worker.jobs`. After any migration, `git diff db/schema.rb | grep -c '^-.*create_table'` MUST be 0.

**Goal:** On every new lead, automatically research the company (AI + web), score legitimacy, classify industry, and generate a Roman-Urdu call script — all per-org with a bring-your-own-Claude key (default to Tecaudex's).

**Architecture:** New `ai` OrganizationFeature (provider claude/openai, encrypted api_key). `Ai::Client` wraps the Anthropic Messages API (HTTParty), with a web-search variant for research. `LeadEnrichmentService` + `CallScriptService` are pure-ish services; `EnrichLeadWorker` + `GenerateCallScriptWorker` (Sidekiq) persist results onto `Customer`. Enrichment auto-runs when a lead is created (incl. from the Odoo connector).

## Tasks
- T1: Register `ai` OrganizationFeature key (providers: claude, openai, deepseek). Mirror the odoo_partner_portal feature-flag task.
- T2: `Ai::Client` service — `.for_organization(org)` resolves provider+key from the `ai` feature (fallback to `Rails.application.credentials.anthropic_api_key` / ENV `ANTHROPIC_API_KEY`). Methods: `#complete(system:, prompt:) -> String` and `#research(prompt:) -> String` (web-search tool). HTTParty POST to api.anthropic.com/v1/messages. Tests stub HTTParty.
- T3: Customer enrichment columns migration: `enrichment_summary:text, industry:string, legitimacy_score:integer, lead_is_junk:boolean, enriched_at:datetime, call_script:text, call_script_generated_at:datetime`.
- T4: `LeadEnrichmentService.call(customer) -> Hash` — builds a research prompt from the customer (name, company, email, phone, idea_description), calls `Ai::Client#research`, parses a JSON block into `{ summary, industry, legitimacy_score (0-100), is_junk }`. Robust JSON extraction. Tests stub Ai::Client.
- T5: `EnrichLeadWorker#perform(customer_id)` — runs the service, writes the columns, sets `enriched_at`. Tenant-safe (without_tenant lookup + with_tenant work). Tests stub the service.
- T6: `CallScriptService.call(customer) -> String` — uses enrichment + `Ai::Client#complete` with the 5-step cold-call framework, Roman-Urdu, returns the script text. Tests stub Ai::Client.
- T7: `GenerateCallScriptWorker#perform(customer_id)` — runs the service, writes `call_script` + timestamp. Tests stub the service.
- T8: Auto-trigger: `Customer after_create :enqueue_enrichment` (guard: skip if a flag/env disables, and chain script gen after enrichment). EnrichLeadWorker enqueues GenerateCallScriptWorker on success. Wire the Odoo connector's `upsert_customer` path so ingested leads enrich too (after_create covers it). Tests assert enqueues with `:sidekiq_fake`.
- T9: Customer UI (Relay) — show enrichment summary + industry + legitimacy + the call script on the customer detail rail, with a "Re-run intelligence" button (POST that enqueues EnrichLeadWorker). Request spec.
