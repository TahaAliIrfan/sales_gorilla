# Demo Builder ("Build Demo" button) — Implementation Plan

> Same TDD + subagent execution. Branch: feat/odoo-portal-connector. Env: `export PATH="$HOME/.rbenv/shims:$PATH"`. NO co-author lines. `:sidekiq_fake` enables `Worker.jobs`. After any migration: `git diff db/schema.rb | grep -c '^-.*create_table'` MUST be 0.

**Goal:** A "Build Demo" button on a lead → classify its industry → ask the demo server (demo.tecaudex.pk) to spin up a fresh **branded Odoo demo DB** seeded for that industry → generate a story-guide PDF → store the demo URL + login + PDF on the lead for the sales team.

**Architecture:** Rails side calls a server-side demo-builder over HTTP via `Demo::ServerClient` (mockable). `DemoBuilderService` maps `customer.industry` → a template key + params (company name, brand) and invokes the client. `BuildDemoWorker` (Sidekiq) persists the result + generates a Grover PDF attached to the Customer. The demo server endpoint (Python, on demo.tecaudex.pk) wraps the parameterized seed scripts — built + deployed separately (not in this repo).

## Rails tasks
- D1: `demo_engine` OrganizationFeature key (provider `odoo`); settings hold `{ server_url, api_key }`.
- D2: Customer demo columns migration: `demo_url:string, demo_db:string, demo_login:string, demo_password:text(encrypted via model), demo_status:string, demo_built_at:datetime`; `has_one_attached :demo_guide` (Active Storage, already in app).
- D3: `Demo::ServerClient` — `.for_organization(org)` resolves `server_url` (default `https://demo.tecaudex.pk`) + `api_key` from the org's `demo_engine` feature (fallback ENV `DEMO_SERVER_URL`/`DEMO_SERVER_KEY`). `#build(company:, industry:, brand:, ref:) -> { "url", "db", "login", "password" }`. HTTParty POST `#{server_url}/build`. Tests stub HTTParty.
- D4: `DemoBuilderService.call(customer) -> Hash` — `INDUSTRY_TEMPLATES = { "Manufacturing"=>"manufacturing", "Retail/Ecommerce"=>"retail", "Real Estate"=>"realestate", "Services"=>"services", ...}`, default "services". Builds params from customer (company, industry→template, ref=customer.id). Calls `Demo::ServerClient.for_organization(org).build(...)`. Tests stub client.
- D5: `BuildDemoWorker#perform(customer_id)` — sets demo_status "building", runs the service, stores `demo_url/db/login/password`, `demo_status "ready"`, `demo_built_at`. On error → demo_status "failed". Then enqueues `GenerateDemoGuideWorker`. Tenant-safe. Tests stub service.
- D6: `DemoGuidePdfService` + `GenerateDemoGuideWorker` — render an HTML story-guide (ERB template using the customer + demo creds) → Grover `.to_pdf` → attach as `customer.demo_guide`. Tests stub Grover.
- D7: "Build Demo" button → `build_demo` member route + controller action (Pundit `build_demo?` mirroring `enrich?`) enqueues `BuildDemoWorker`; rail section shows demo status + link + login + the PDF download. Request spec.

## Server-side (separate, on demo.tecaudex.pk — not this repo)
A small auth'd HTTP endpoint `POST /build` that: creates a fresh Odoo DB, runs the parameterized industry seed (company name + brand), generates branded images, sets an admin login, returns `{ url, db, login, password }`. Wraps the existing seed scripts. Deployed via the EC2 box.
