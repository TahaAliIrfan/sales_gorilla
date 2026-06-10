# Meta Lead Ads — Setup Runbook (give this to Claude Code)

Goal: stand up a **new** Meta app called **SalesGorilla** and finish wiring the
self-service Lead Ads integration so each org can connect its own Facebook Page
and have leads flow into the CRM automatically.

The CODE is already built and verified (models, webhook, OAuth flow, worker, UI).
What remains is (A) creating + configuring the Meta app in the dashboard — a
human browser task — and (B) pasting two secrets into Rails credentials + deploy.

**App already created (2026-06-10):** name **SalesGorilla**, App ID
`2793001874407592`, Business **Tecaudex** (verified). App ID + verify token are
already in Rails credentials; **App Secret still needs to be pasted in (B2).**

**Fixed URLs (production host = `salesgorilla.app`):**
- Webhook callback: `https://salesgorilla.app/webhooks/facebook`  ← matches dashboard; code aliases this
- OAuth redirect:   `https://salesgorilla.app/meta_lead_ads/callback`
  - ⚠️ The dashboard was initially set to `/auth/facebook/callback` — that path
    is already claimed by the app's Google login route (`/auth/:provider/callback`
    → SessionsController) and will break. **Change it to `/meta_lead_ads/callback`.**
- Webhook verify token: `salesgorilla_verify_token` (matches dashboard)
- Privacy policy (Meta requires one): `https://salesgorilla.app/privacy` (confirm this page exists)

> If the app is actually served from a non-tenant subdomain (e.g.
> `app.salesgorilla.app`) instead of the bare apex, use that host in BOTH URLs.
> Any non-tenant host works; org subdomains (`acme.salesgorilla.app`) do NOT.

---

## Part A — Human steps in Meta dashboard (≈20 min)

Do these at https://developers.facebook.com while logged in with the Business
account that manages the Facebook Pages.

### A1. Create the app
1. **My Apps → Create App**.
2. Use case: **Other** → Type: **Business** → next.
3. App name: **SalesGorilla**. Contact email: your admin email. Create.
4. From **App settings → Basic**, copy the **App ID** and **App Secret**
   (click *Show*). You'll hand these to Claude Code in Part B.
5. On the same page set **App Domains** = `salesgorilla.app`, add a
   **Privacy Policy URL** = `https://salesgorilla.app/privacy`, choose a
   Category, and **Save changes**.

### A2. Add Facebook Login
1. **Add Product → Facebook Login for Business → Set up.**
2. **Facebook Login → Settings**:
   - Client OAuth Login: **On**
   - Web OAuth Login: **On**
   - **Valid OAuth Redirect URIs**: `https://salesgorilla.app/meta_lead_ads/callback`
   - Save changes.

### A3. Add Webhooks → subscribe `leadgen`
1. **Add Product → Webhooks.**
2. Topic dropdown: **Page**.
3. **Callback URL**: `https://salesgorilla.app/webhooks/meta/lead_ads`
4. **Verify Token**: the value Claude Code prints in step **B1**.
5. Click **Verify and Save** (Meta hits the GET endpoint; it should succeed).
6. Under the Page topic, **Subscribe** to the **`leadgen`** field.

### A4. Request permissions (App Review)
Under **App Review → Permissions and Features**, request **Advanced Access** for
exactly the scopes the code requests (in `MetaLeadAdsService::OAUTH_SCOPES`):
- `leads_retrieval`        — fetch each lead's field data
- `pages_show_list`        — list the admin's Pages
- `pages_read_engagement`  — read Page info during connect
- `pages_manage_metadata`  — **required** to subscribe a Page to the `leadgen` webhook
- `ads_management`         — required by some lead forms

⚠️ The first pass queued `pages_manage_ads` and `business_management`, which the
code does **not** use, and missed `pages_manage_metadata`, which it **does** need
(no metadata permission → can't subscribe the Page → no leads arrive). Request
the five above; you can drop `pages_manage_ads` / `business_management`.

**Unlocking the "Request advanced access" buttons:** Meta requires one real API
call from the app first. The simplest way is to just complete the connect flow
once after deploy (step C2) — it calls `/me/accounts` and `/{page}/subscribed_apps`,
which satisfies this. Or make a quick `GET /me` from the Graph API Explorer using
the app. Then the buttons turn active.

Notes:
- This usually requires **Business Verification** (App Review → complete it).
- Until approved you can still TEST: add yourself under
  **App Roles → Roles** as Admin/Tester, and any Page **you** admin can be
  connected with Standard Access.
- Record a short screencast of the connect flow for the review submission
  (Meta asks how each permission is used: "admin connects their Page so new
  Lead Ads leads sync into our CRM").

### A5. Go Live
Flip the app from **Development** to **Live** (top bar toggle) once review passes.

---

## Part B — Claude Code steps (code + credentials)

### B1. (Already done) verify token + App ID are in credentials
`meta_app_id` = `2793001874407592` and `meta_webhook_verify_token` =
`salesgorilla_verify_token` are already set. To print the token if needed:
```bash
bin/rails runner 'puts Rails.application.credentials.dig(:meta_webhook_verify_token)'
```

### B2. Paste the App Secret into credentials  ← ONLY remaining credential step
Get it from **App settings → Basic → App Secret → Show** in the dashboard.
```bash
EDITOR="code --wait" bin/rails credentials:edit   # or: EDITOR=nano / EDITOR=vim
```
Set (the empty placeholder already exists):
```yaml
meta_app_secret: <APP_SECRET>
```
Save & close. Then confirm:
```bash
bin/rails runner 'puts MetaLeadAdsService.configured?'   # must print true
```

### B3. Ensure the production master key is present on the server
The app must boot with `RAILS_MASTER_KEY` (or `config/master.key`) so it can
decrypt credentials. Confirm the deploy environment has it; otherwise the new
keys won't be readable in production.

### B4. Deploy / restart
Deploy the `revamp` branch (or whichever ships to `salesgorilla.app`) and
restart web + Sidekiq so the new routes, controllers, worker, and credentials
load. No DB migration is needed in prod beyond the one already created
(`meta_page_connections`) — run `bin/rails db:migrate` on the server if it
hasn't been applied there yet.

### B5. Smoke-test the public webhook (after deploy)
```bash
TOKEN=$(bin/rails runner 'print Rails.application.credentials.dig(:meta_webhook_verify_token)')
curl -s "https://salesgorilla.app/webhooks/facebook?hub.mode=subscribe&hub.verify_token=$TOKEN&hub.challenge=PING123"
# Expect: PING123
```

---

## Part C — Verify the whole loop

1. As an org **admin**, go to **Settings → Features → Meta Lead Ads** on the
   org subdomain (`<org>.salesgorilla.app`).
2. Click **Connect Facebook Page** → authorize → pick the Page(s).
   - Back in Settings you should see the Page listed as **active**; set its
     **lead source** (default `Inbound`).
3. Submit a test lead via Meta's
   [Lead Ads Testing Tool](https://developers.facebook.com/tools/lead-ads-testing)
   for that Page/form.
4. Within seconds a new **Customer** should appear with `meta_lead_id` set and
   any custom form answers in the notes. Check `MetaInboundLead.last.status`
   (`processed`) and Sidekiq's `followups` queue if it doesn't.

---

## Local testing (optional, before production)

Meta can't reach `localhost`, so expose dev over HTTPS with a tunnel:
```bash
ngrok http 3000   # gives e.g. https://abc123.ngrok.app
```
Then in a SEPARATE dev-only Meta app (don't reuse prod), set the callback to
`https://abc123.ngrok.app/webhooks/meta/lead_ads` and OAuth redirect to
`https://abc123.ngrok.app/meta_lead_ads/callback`. Add `abc123.ngrok.app` to
`config.hosts` in `config/environments/development.rb`. Dev tenant subdomains
use `*.lvh.me:3000`.

---

## Reference — what's already in the codebase

| Concern | Location |
|---|---|
| Webhook (verify + receive, HMAC-SHA256) | `app/controllers/webhooks/meta_lead_ads_controller.rb`, routes `GET/POST /webhooks/meta/lead_ads` |
| Self-service OAuth connect/callback | `app/controllers/meta_lead_ads/connections_controller.rb`, routes `/meta_lead_ads/connect`, `/meta_lead_ads/callback` |
| Per-page source / disconnect | `app/controllers/settings/meta_page_connections_controller.rb` |
| Graph API (v25.0) calls | `app/services/meta_lead_ads_service.rb` |
| Page→org routing + token (encrypted) | `app/models/meta_page_connection.rb` (table `meta_page_connections`) |
| Inbound lead record | `app/models/meta_inbound_lead.rb` (table `meta_inbound_leads`) |
| Lead → Customer mapping | `app/workers/process_meta_inbound_lead_worker.rb` (Sidekiq `followups` queue) |
| Settings UI | `app/views/settings/features/_lead_ads_fields.html.erb`, `_lead_ads_connections.html.erb` |
| Feature flag | `OrganizationFeature` key `meta_lead_ads`, provider `meta` |
| Credentials keys | `meta_app_id`, `meta_app_secret`, `meta_webhook_verify_token` |
