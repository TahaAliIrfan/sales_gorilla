# Odoo Partner Portal Connector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let any partner org auto-sync its odoo.com partner-portal leads into the CRM as `Customer`s and push status changes back to the portal, via a saved headless-browser session.

**Architecture:** No partner API exists, so a saved (cookie) browser session drives the portal headlessly. Ingest and write-back run in Sidekiq workers that shell out to a Node/Puppeteer script (JSON in/out) and upsert `Customer`s. Everything is per-`Organization` and mirrors the existing Meta inbound pattern (`MetaPageConnection` / `MetaInboundLead` / `ProcessMetaInboundLeadWorker`).

**Tech Stack:** Rails 7.1, PostgreSQL, RSpec + FactoryBot, Sidekiq + sidekiq-scheduler, `acts_as_tenant`, Rails 7 `encrypts`, Node 18 + Puppeteer (invoked via `Open3`).

## Global Constraints

- Every new table/model is per-org: `belongs_to :organization` + `acts_as_tenant :organization`. Verbatim values copied below.
- Secrets at rest use Rails `encrypts` (session cookies, credentials) — never plaintext columns.
- Webhook/root-host lookups that run without a tenant use `ActsAsTenant.without_tenant { ... }`.
- New `OrganizationFeature` key: exactly `"odoo_partner_portal"`; provider exactly `"odoo"`.
- `Customer.lead_source` value for these leads: exactly `"Odoo Partner Portal"`.
- Node script path: `lib/odoo_portal/portal_agent.js`. Ruby↔Node contract: one JSON object on stdin, one JSON object on stdout.
- Tests: RSpec, `build`/`create` via FactoryBot, files under `spec/**`. Run a single spec with `bundle exec rspec path:line`.
- Do NOT commit to `revamp` directly — this plan's commits land on a feature branch `feat/odoo-portal-connector` (created in Task 0).

---

### Task 0: Branch + Node agent scaffold

**Files:**
- Create: `lib/odoo_portal/portal_agent.js`
- Create: `lib/odoo_portal/README.md`

**Interfaces:**
- Produces: a CLI Node agent. Contract: `node lib/odoo_portal/portal_agent.js` reads one JSON object `{ action, cookies, base_url, selectors, payload }` from stdin and prints one JSON object `{ ok, data, error }` to stdout. `action` ∈ `validate_session | list_leads | show_lead | write_action`.

- [ ] **Step 1: Create the branch**

```bash
cd ~/Projects/crm-backend
git checkout -b feat/odoo-portal-connector
```

- [ ] **Step 2: Write the Node agent (skeleton with the 4 actions)**

`lib/odoo_portal/portal_agent.js`:
```js
// Headless Puppeteer agent for the Odoo partner portal. Stateless: receives a
// saved cookie jar + an action on stdin, returns JSON on stdout. Selectors are
// passed in (captured during Task 6) so Ruby owns config, not this script.
const puppeteer = require("puppeteer");

function readStdin() {
  return new Promise((resolve) => {
    let buf = "";
    process.stdin.on("data", (d) => (buf += d));
    process.stdin.on("end", () => resolve(buf));
  });
}

async function withPage(cookies, baseUrl, fn) {
  const browser = await puppeteer.launch({
    headless: "new",
    args: ["--no-sandbox", "--disable-dev-shm-usage"],
  });
  try {
    const page = await browser.newPage();
    if (cookies && cookies.length) await page.setCookie(...cookies);
    return await fn(page, browser);
  } finally {
    await browser.close();
  }
}

async function main() {
  const input = JSON.parse((await readStdin()) || "{}");
  const { action, cookies = [], base_url: baseUrl, selectors = {}, payload = {} } = input;
  try {
    const data = await withPage(cookies, baseUrl, async (page) => {
      switch (action) {
        case "validate_session": {
          const res = await page.goto(`${baseUrl}/my/leads`, { waitUntil: "networkidle2" });
          const loggedIn = !page.url().includes("/web/login");
          return { logged_in: loggedIn && res.ok() };
        }
        case "list_leads": {
          await page.goto(`${baseUrl}/my/leads`, { waitUntil: "networkidle2" });
          return await page.$$eval(selectors.row || "tr[data-lead-id], .o_portal_my_doc_table tr", (rows) =>
            rows
              .map((r) => ({
                portal_lead_id: r.getAttribute("data-lead-id") || (r.querySelector("a") || {}).href || null,
                title: (r.innerText || "").trim().slice(0, 200),
              }))
              .filter((x) => x.portal_lead_id)
          );
        }
        case "show_lead": {
          await page.goto(payload.url, { waitUntil: "networkidle2" });
          return await page.evaluate(() => ({ html: document.querySelector("main")?.innerHTML || document.body.innerHTML }));
        }
        case "write_action": {
          await page.goto(payload.url, { waitUntil: "networkidle2" });
          // payload.kind: "note" | "exception" | "stage"
          return { performed: payload.kind, note: payload.note || null };
        }
        default:
          throw new Error(`unknown action: ${action}`);
      }
    });
    process.stdout.write(JSON.stringify({ ok: true, data }));
  } catch (e) {
    process.stdout.write(JSON.stringify({ ok: false, error: String(e && e.message ? e.message : e) }));
  }
}

main();
```

`lib/odoo_portal/README.md`:
```md
# Odoo Portal Node Agent
Stateless Puppeteer CLI driven by `OdooPortal::BrowserRunner` (Ruby).
Contract: JSON on stdin -> JSON on stdout. Actions: validate_session,
list_leads, show_lead, write_action. Selectors are passed in from Ruby and
captured against the live portal in the implementation plan (Task 6).
```

- [ ] **Step 3: Commit**

```bash
git add lib/odoo_portal/
git commit -m "chore(odoo-portal): scaffold node puppeteer agent + branch"
```

---

### Task 1: Register the `odoo_partner_portal` feature

**Files:**
- Modify: `app/models/organization_feature.rb` (KEYS, PROVIDERS)
- Test: `spec/models/organization_feature_spec.rb`

**Interfaces:**
- Produces: `OrganizationFeature` accepts `key: "odoo_partner_portal"`, `provider: "odoo"`. `org.feature_enabled?(:odoo_partner_portal)` works (existing helper).

- [ ] **Step 1: Write the failing test**

`spec/models/organization_feature_spec.rb` (add inside the file, or create it):
```ruby
require "rails_helper"

RSpec.describe OrganizationFeature do
  it "accepts the odoo_partner_portal feature with the odoo provider" do
    org = create(:organization)
    feature = org.features.build(key: "odoo_partner_portal", provider: "odoo", enabled: true)
    expect(feature).to be_valid
  end

  it "rejects an unknown provider for odoo_partner_portal" do
    org = create(:organization)
    feature = org.features.build(key: "odoo_partner_portal", provider: "twilio")
    expect(feature).not_to be_valid
    expect(feature.errors[:provider]).to be_present
  end
end
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bundle exec rspec spec/models/organization_feature_spec.rb`
Expected: FAIL — `"odoo_partner_portal" is not included in the list`.

- [ ] **Step 3: Add the key + provider**

In `app/models/organization_feature.rb`:
```ruby
  KEYS = %w[calling transcription meta_conversions meta_lead_ads whatsapp odoo_partner_portal].freeze

  PROVIDERS = {
    "calling" => %w[twilio].freeze,
    "transcription" => %w[deepgram].freeze,
    "meta_conversions" => %w[meta].freeze,
    "meta_lead_ads" => %w[meta].freeze,
    "whatsapp" => %w[twilio].freeze,
    "odoo_partner_portal" => %w[odoo].freeze
  }.freeze
```

- [ ] **Step 4: Run it, verify it passes**

Run: `bundle exec rspec spec/models/organization_feature_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/models/organization_feature.rb spec/models/organization_feature_spec.rb
git commit -m "feat(odoo-portal): register odoo_partner_portal feature flag"
```

---

### Task 2: `OdooPortalConnection` model (encrypted session)

**Files:**
- Create: `db/migrate/XXXXXX_create_odoo_portal_connections.rb`
- Create: `app/models/odoo_portal_connection.rb`
- Create: `spec/factories/odoo_portal_connections.rb`
- Test: `spec/models/odoo_portal_connection_spec.rb`

**Interfaces:**
- Produces: `OdooPortalConnection` with columns `organization_id, base_url, session_cookies(text, encrypted), status, last_error, last_synced_at, watch_from(text), watch_subject(text)`. STATUSES `%w[active needs_reauth error]`. Methods: `active?`, `mark_needs_reauth!`, `mark_error!(msg)`, `touch_synced!`, scope `.active`, `self.for_organization(org)`.

- [ ] **Step 1: Write the migration**

`db/migrate/XXXXXX_create_odoo_portal_connections.rb` (use `rails g migration` to get the timestamp, then replace body):
```ruby
class CreateOdooPortalConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :odoo_portal_connections do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :base_url, null: false, default: "https://www.odoo.com"
      t.text   :session_cookies            # encrypted JSON cookie jar
      t.string :status, null: false, default: "needs_reauth"
      t.text   :last_error
      t.datetime :last_synced_at
      t.string :watch_from                 # sender match for the trigger email
      t.string :watch_subject              # subject match for the trigger email
      t.timestamps
      t.index [:organization_id], unique: true
    end
  end
end
```

- [ ] **Step 2: Migrate**

Run: `bundle exec rails db:migrate`
Expected: creates `odoo_portal_connections`; `db/schema.rb` updated.

- [ ] **Step 3: Write the factory**

`spec/factories/odoo_portal_connections.rb`:
```ruby
FactoryBot.define do
  factory :odoo_portal_connection do
    organization
    base_url { "https://www.odoo.com" }
    status { "active" }
    session_cookies { [{ "name" => "session_id", "value" => "abc", "domain" => ".odoo.com" }].to_json }
  end
end
```

- [ ] **Step 4: Write the failing test**

`spec/models/odoo_portal_connection_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe OdooPortalConnection do
  it "is active when status is active" do
    expect(build(:odoo_portal_connection, status: "active")).to be_active
  end

  it "mark_needs_reauth! flips status and clears cookies" do
    conn = create(:odoo_portal_connection, status: "active")
    conn.mark_needs_reauth!
    expect(conn.reload.status).to eq("needs_reauth")
  end

  it "for_organization finds the row ignoring tenant scope" do
    org = create(:organization)
    conn = ActsAsTenant.with_tenant(org) { create(:odoo_portal_connection, organization: org) }
    found = ActsAsTenant.without_tenant { OdooPortalConnection.for_organization(org) }
    expect(found).to eq(conn)
  end
end
```

- [ ] **Step 5: Run it, verify it fails**

Run: `bundle exec rspec spec/models/odoo_portal_connection_spec.rb`
Expected: FAIL — `uninitialized constant OdooPortalConnection`.

- [ ] **Step 6: Write the model**

`app/models/odoo_portal_connection.rb`:
```ruby
# A partner's authenticated odoo.com portal session, captured once via the
# connect flow and reused by the headless scraper/writer. Mirrors
# MetaPageConnection: per-org routing + encrypted secret + health status.
class OdooPortalConnection < ApplicationRecord
  belongs_to :organization
  acts_as_tenant :organization

  encrypts :session_cookies

  STATUSES = %w[active needs_reauth error].freeze

  validates :base_url, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }

  def self.for_organization(org)
    ActsAsTenant.without_tenant { find_by(organization_id: org.id) }
  end

  def active? = status == "active"

  def cookies
    JSON.parse(session_cookies.presence || "[]")
  rescue JSON::ParserError
    []
  end

  def mark_needs_reauth!
    update_columns(status: "needs_reauth", session_cookies: nil)
  end

  def mark_error!(message)
    update_columns(status: "error", last_error: message.to_s.truncate(1000))
  end

  def touch_synced!
    update_columns(last_synced_at: Time.current, last_error: nil)
  end
end
```

- [ ] **Step 7: Run it, verify it passes**

Run: `bundle exec rspec spec/models/odoo_portal_connection_spec.rb`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add db/migrate db/schema.rb app/models/odoo_portal_connection.rb spec/factories/odoo_portal_connections.rb spec/models/odoo_portal_connection_spec.rb
git commit -m "feat(odoo-portal): OdooPortalConnection model with encrypted session"
```

---

### Task 3: `PartnerPortalLead` sync record

**Files:**
- Create: `db/migrate/XXXXXX_create_partner_portal_leads.rb`
- Create: `app/models/partner_portal_lead.rb`
- Create: `spec/factories/partner_portal_leads.rb`
- Test: `spec/models/partner_portal_lead_spec.rb`

**Interfaces:**
- Produces: `PartnerPortalLead` columns `organization_id, customer_id(nullable), portal_lead_id, status, raw_payload(jsonb), error_message, processed_at`. STATUSES `%w[received processed failed duplicate]`. Methods `mark_processed!(customer)`, `mark_failed!(msg)`, `mark_duplicate!(customer)`. Unique `(organization_id, portal_lead_id)`.

- [ ] **Step 1: Write the migration**

`db/migrate/XXXXXX_create_partner_portal_leads.rb`:
```ruby
class CreatePartnerPortalLeads < ActiveRecord::Migration[7.1]
  def change
    create_table :partner_portal_leads do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :customer, null: true, foreign_key: true
      t.string  :portal_lead_id, null: false
      t.string  :status, null: false, default: "received"
      t.jsonb   :raw_payload, null: false, default: {}
      t.text    :error_message
      t.datetime :processed_at
      t.timestamps
      t.index [:organization_id, :portal_lead_id], unique: true, name: "idx_portal_leads_on_org_and_portal_id"
    end
  end
end
```

- [ ] **Step 2: Migrate**

Run: `bundle exec rails db:migrate`

- [ ] **Step 3: Write the factory**

`spec/factories/partner_portal_leads.rb`:
```ruby
FactoryBot.define do
  factory :partner_portal_lead do
    organization
    sequence(:portal_lead_id) { |n| "lead-#{n}" }
    status { "received" }
    raw_payload { { "title" => "Some Lead" } }
  end
end
```

- [ ] **Step 4: Write the failing test**

`spec/models/partner_portal_lead_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe PartnerPortalLead do
  it "is unique on portal_lead_id within an organization" do
    org = create(:organization)
    create(:partner_portal_lead, organization: org, portal_lead_id: "L1")
    dup = build(:partner_portal_lead, organization: org, portal_lead_id: "L1")
    expect(dup).not_to be_valid
  end

  it "mark_processed! links the customer and flips status" do
    org = create(:organization)
    customer = ActsAsTenant.with_tenant(org) { create(:customer, organization: org) }
    lead = create(:partner_portal_lead, organization: org)
    lead.mark_processed!(customer)
    expect(lead.reload).to have_attributes(status: "processed", customer_id: customer.id)
  end
end
```

- [ ] **Step 5: Run it, verify it fails**

Run: `bundle exec rspec spec/models/partner_portal_lead_spec.rb`
Expected: FAIL — `uninitialized constant PartnerPortalLead`.

- [ ] **Step 6: Write the model**

`app/models/partner_portal_lead.rb`:
```ruby
# One scraped lead from the partner portal. Created "received", upserted into a
# Customer, then marked processed/failed/duplicate. Mirrors MetaInboundLead.
class PartnerPortalLead < ApplicationRecord
  belongs_to :organization
  belongs_to :customer, optional: true
  acts_as_tenant :organization

  STATUSES = %w[received processed failed duplicate].freeze

  validates :portal_lead_id, presence: true,
            uniqueness: { scope: :organization_id }
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "received") }

  def mark_processed!(customer)
    update!(customer: customer, status: "processed", processed_at: Time.current, error_message: nil)
  end

  def mark_failed!(message)
    update!(status: "failed", processed_at: Time.current, error_message: message.to_s.truncate(1000))
  end

  def mark_duplicate!(customer)
    update!(customer: customer, status: "duplicate", processed_at: Time.current)
  end
end
```

- [ ] **Step 7: Run it, verify it passes**

Run: `bundle exec rspec spec/models/partner_portal_lead_spec.rb`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add db/migrate db/schema.rb app/models/partner_portal_lead.rb spec/factories/partner_portal_leads.rb spec/models/partner_portal_lead_spec.rb
git commit -m "feat(odoo-portal): PartnerPortalLead sync record"
```

---

### Task 4: Customer portal columns + dedupe

**Files:**
- Create: `db/migrate/XXXXXX_add_portal_fields_to_customers.rb`
- Test: `spec/models/customer_portal_fields_spec.rb`

**Interfaces:**
- Produces: `customers.portal_lead_id` (string, indexed) and `customers.portal_last_pushed_at` (datetime). Used by the sync worker (dedupe) and write-back (loop guard).

- [ ] **Step 1: Write the migration**

`db/migrate/XXXXXX_add_portal_fields_to_customers.rb`:
```ruby
class AddPortalFieldsToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :portal_lead_id, :string
    add_column :customers, :portal_last_pushed_at, :datetime
    add_index  :customers, [:organization_id, :portal_lead_id]
  end
end
```

- [ ] **Step 2: Migrate**

Run: `bundle exec rails db:migrate`

- [ ] **Step 3: Write the test**

`spec/models/customer_portal_fields_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe Customer do
  it "persists portal_lead_id" do
    org = create(:organization)
    c = ActsAsTenant.with_tenant(org) { create(:customer, organization: org, portal_lead_id: "L9") }
    expect(c.reload.portal_lead_id).to eq("L9")
  end
end
```

- [ ] **Step 4: Run it, verify it passes**

Run: `bundle exec rspec spec/models/customer_portal_fields_spec.rb`
Expected: PASS (columns exist after migrate).

- [ ] **Step 5: Commit**

```bash
git add db/migrate db/schema.rb spec/models/customer_portal_fields_spec.rb
git commit -m "feat(odoo-portal): add portal dedupe + push-guard columns to customers"
```

---

### Task 5: `OdooPortal::LeadParser` (pure mapping)

**Files:**
- Create: `app/services/odoo_portal/lead_parser.rb`
- Create: `spec/fixtures/odoo_portal/lead_show.html`
- Test: `spec/services/odoo_portal/lead_parser_spec.rb`

**Interfaces:**
- Consumes: a raw payload hash `{ "portal_lead_id" => String, "title" => String, "html" => String }`.
- Produces: `OdooPortal::LeadParser.call(payload) -> Hash` with Customer attrs: `name, company, email, phone, address, lead_source, status, portal_lead_id`.

- [ ] **Step 1: Create the HTML fixture (representative portal lead detail)**

`spec/fixtures/odoo_portal/lead_show.html`:
```html
<main>
  <h2>Lead - HASSAN (animeworldpak.com) Registration</h2>
  <p>Customer: <span class="o_customer">animeworldpak.com</span></p>
  <p>Contact: HASSAN</p>
  <p>Phone: +92 344 8431169</p>
  <p>Email: husnainxbad@gmail.com</p>
  <p>Address: Gujranwala</p>
  <p>Stage: New</p>
</main>
```

- [ ] **Step 2: Write the failing test**

`spec/services/odoo_portal/lead_parser_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe OdooPortal::LeadParser do
  let(:html) { Rails.root.join("spec/fixtures/odoo_portal/lead_show.html").read }
  subject(:attrs) { described_class.call("portal_lead_id" => "L1", "title" => "Lead", "html" => html) }

  it "maps the core contact fields" do
    expect(attrs).to include(
      company: "animeworldpak.com",
      phone: "+92 344 8431169",
      email: "husnainxbad@gmail.com",
      address: "Gujranwala",
      lead_source: "Odoo Partner Portal",
      portal_lead_id: "L1"
    )
  end

  it "uses the contact line as the customer name" do
    expect(attrs[:name]).to eq("HASSAN")
  end
end
```

- [ ] **Step 3: Run it, verify it fails**

Run: `bundle exec rspec spec/services/odoo_portal/lead_parser_spec.rb`
Expected: FAIL — `uninitialized constant OdooPortal::LeadParser`.

- [ ] **Step 4: Write the parser**

`app/services/odoo_portal/lead_parser.rb`:
```ruby
require "nokogiri"

module OdooPortal
  # Pure transform: a scraped lead payload -> Customer attribute hash. No DB, no
  # browser. Selector-light + regex fallbacks so portal markup tweaks don't break
  # ingestion. Field extraction is label-driven ("Phone: ...").
  class LeadParser
    LABELS = {
      name: /Contact:\s*(.+)/i,
      company: /Customer:\s*(.+)/i,
      phone: /Phone:\s*(.+)/i,
      email: /Email:\s*(.+)/i,
      address: /Address:\s*(.+)/i,
      status: /Stage:\s*(.+)/i
    }.freeze

    def self.call(payload) = new(payload).call

    def initialize(payload)
      @payload = payload
      @text = Nokogiri::HTML(payload["html"].to_s).text
    end

    def call
      LABELS.transform_values { |re| @text[re, 1]&.strip }.merge(
        portal_lead_id: @payload["portal_lead_id"],
        lead_source: "Odoo Partner Portal"
      ).compact
    end
  end
end
```

- [ ] **Step 5: Run it, verify it passes**

Run: `bundle exec rspec spec/services/odoo_portal/lead_parser_spec.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/services/odoo_portal/lead_parser.rb spec/fixtures/odoo_portal/lead_show.html spec/services/odoo_portal/lead_parser_spec.rb
git commit -m "feat(odoo-portal): pure LeadParser (portal html -> customer attrs)"
```

---

### Task 6: `OdooPortal::BrowserRunner` (Ruby↔Node bridge) + capture selectors

**Files:**
- Create: `app/services/odoo_portal/browser_runner.rb`
- Modify: `lib/odoo_portal/portal_agent.js` (finalize selectors from capture)
- Test: `spec/services/odoo_portal/browser_runner_spec.rb`

**Interfaces:**
- Consumes: `OdooPortalConnection#cookies`, `#base_url`.
- Produces: `OdooPortal::BrowserRunner.new(connection).run(action, payload = {}) -> Hash` (the agent's `data`). Raises `OdooPortal::BrowserRunner::SessionExpired` when the agent reports not logged in; `OdooPortal::BrowserRunner::AgentError` on `{ ok: false }`.

- [ ] **Step 1: Write the failing test (stub Open3 — no real browser)**

`spec/services/odoo_portal/browser_runner_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe OdooPortal::BrowserRunner do
  let(:conn) { build(:odoo_portal_connection) }
  subject(:runner) { described_class.new(conn) }

  it "returns the agent data on success" do
    allow(Open3).to receive(:capture3).and_return([{ ok: true, data: [{ "portal_lead_id" => "L1" }] }.to_json, "", instance_double(Process::Status, success?: true)])
    expect(runner.run("list_leads")).to eq([{ "portal_lead_id" => "L1" }])
  end

  it "raises AgentError when the agent reports failure" do
    allow(Open3).to receive(:capture3).and_return([{ ok: false, error: "boom" }.to_json, "", instance_double(Process::Status, success?: true)])
    expect { runner.run("list_leads") }.to raise_error(described_class::AgentError, /boom/)
  end

  it "raises SessionExpired when validate_session reports logged_in false" do
    allow(Open3).to receive(:capture3).and_return([{ ok: true, data: { "logged_in" => false } }.to_json, "", instance_double(Process::Status, success?: true)])
    expect { runner.run("validate_session") }.to raise_error(described_class::SessionExpired)
  end
end
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bundle exec rspec spec/services/odoo_portal/browser_runner_spec.rb`
Expected: FAIL — `uninitialized constant OdooPortal::BrowserRunner`.

- [ ] **Step 3: Write the runner**

`app/services/odoo_portal/browser_runner.rb`:
```ruby
require "open3"

module OdooPortal
  # Thin bridge to the Node/Puppeteer agent. One process per action; JSON in/out.
  class BrowserRunner
    class AgentError < StandardError; end
    class SessionExpired < StandardError; end

    SCRIPT = Rails.root.join("lib/odoo_portal/portal_agent.js").to_s

    # Captured from the live portal in Step 5. Defaults are sane fallbacks.
    SELECTORS = {
      "row" => ".o_portal_my_doc_table tbody tr"
    }.freeze

    def initialize(connection)
      @connection = connection
    end

    def run(action, payload = {})
      input = {
        action: action,
        base_url: @connection.base_url,
        cookies: @connection.cookies,
        selectors: SELECTORS,
        payload: payload
      }.to_json

      stdout, stderr, status = Open3.capture3("node", SCRIPT, stdin_data: input)
      raise AgentError, "node exited: #{stderr.presence || 'unknown'}" unless status.success?

      parsed = JSON.parse(stdout.presence || "{}")
      raise AgentError, parsed["error"].to_s unless parsed["ok"]

      data = parsed["data"]
      raise SessionExpired if action == "validate_session" && data.is_a?(Hash) && data["logged_in"] == false

      data
    end
  end
end
```

- [ ] **Step 4: Run it, verify it passes**

Run: `bundle exec rspec spec/services/odoo_portal/browser_runner_spec.rb`
Expected: PASS.

- [ ] **Step 5: Capture real selectors against the live portal (manual, one-time)**

```bash
# With a real saved cookie jar in /tmp/cookies.json captured from a logged-in
# odoo.com partner session, dump the leads list + one lead's HTML:
echo '{"action":"list_leads","base_url":"https://www.odoo.com","cookies":'"$(cat /tmp/cookies.json)"',"selectors":{}}' | node lib/odoo_portal/portal_agent.js | tee /tmp/list.json
```
Inspect `/tmp/list.json`. If the default `row` selector returned rows, keep it. If empty, open the portal in a browser, find the leads-table row selector, and update `SELECTORS["row"]` in `browser_runner.rb` AND the `list_leads`/`show_lead` selectors in `lib/odoo_portal/portal_agent.js`. Save one real lead-detail page to `spec/fixtures/odoo_portal/lead_show.html` (replacing the placeholder) and re-run Task 5's spec to confirm the parser still maps real markup.

- [ ] **Step 6: Commit**

```bash
git add app/services/odoo_portal/browser_runner.rb lib/odoo_portal/portal_agent.js spec/services/odoo_portal/browser_runner_spec.rb
git commit -m "feat(odoo-portal): BrowserRunner ruby<->node bridge + captured selectors"
```

---

### Task 7: `OdooPortal::Scraper` (list + show → raw lead hashes)

**Files:**
- Create: `app/services/odoo_portal/scraper.rb`
- Test: `spec/services/odoo_portal/scraper_spec.rb`

**Interfaces:**
- Consumes: `OdooPortal::BrowserRunner`.
- Produces: `OdooPortal::Scraper.new(connection).fetch_new(known_ids:) -> Array<Hash>` where each hash is `{ "portal_lead_id" =>, "title" =>, "html" => }` for leads whose `portal_lead_id` is not in `known_ids`.

- [ ] **Step 1: Write the failing test**

`spec/services/odoo_portal/scraper_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe OdooPortal::Scraper do
  let(:conn) { build(:odoo_portal_connection) }
  let(:runner) { instance_double(OdooPortal::BrowserRunner) }
  subject(:scraper) { described_class.new(conn, runner: runner) }

  before do
    allow(runner).to receive(:run).with("validate_session").and_return("logged_in" => true)
    allow(runner).to receive(:run).with("list_leads").and_return([
      { "portal_lead_id" => "L1", "title" => "A", "url" => "u1" },
      { "portal_lead_id" => "L2", "title" => "B", "url" => "u2" }
    ])
    allow(runner).to receive(:run).with("show_lead", { "url" => "u2" }).and_return("html" => "<main>B detail</main>")
  end

  it "returns only unknown leads, enriched with detail html" do
    result = scraper.fetch_new(known_ids: ["L1"])
    expect(result.map { |h| h["portal_lead_id"] }).to eq(["L2"])
    expect(result.first["html"]).to include("B detail")
  end
end
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bundle exec rspec spec/services/odoo_portal/scraper_spec.rb`
Expected: FAIL — `uninitialized constant OdooPortal::Scraper`.

- [ ] **Step 3: Write the scraper**

`app/services/odoo_portal/scraper.rb`:
```ruby
module OdooPortal
  # Diffs the portal leads list against already-known ids and pulls detail HTML
  # for the new ones only. Validates the session up front so an expired session
  # surfaces as SessionExpired before we do any work.
  class Scraper
    def initialize(connection, runner: BrowserRunner.new(connection))
      @runner = runner
    end

    def fetch_new(known_ids:)
      @runner.run("validate_session")
      list = Array(@runner.run("list_leads"))
      list.reject { |row| known_ids.include?(row["portal_lead_id"]) }.map do |row|
        detail = @runner.run("show_lead", "url" => row["url"])
        row.merge("html" => detail["html"])
      end
    end
  end
end
```

- [ ] **Step 4: Run it, verify it passes**

Run: `bundle exec rspec spec/services/odoo_portal/scraper_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/odoo_portal/scraper.rb spec/services/odoo_portal/scraper_spec.rb
git commit -m "feat(odoo-portal): Scraper diffs list + pulls new lead detail"
```

---

### Task 8: `OdooPortalSyncWorker` (orchestrate ingest)

**Files:**
- Create: `app/workers/odoo_portal_sync_worker.rb`
- Test: `spec/workers/odoo_portal_sync_worker_spec.rb`

**Interfaces:**
- Consumes: `OdooPortalConnection`, `OdooPortal::Scraper`, `OdooPortal::LeadParser`, `PartnerPortalLead`, `Customer`.
- Produces: `OdooPortalSyncWorker.new.perform(organization_id)`. For each new scraped lead: create `PartnerPortalLead`, upsert `Customer` by `(organization, portal_lead_id)`, `mark_processed!`. On `SessionExpired`: `connection.mark_needs_reauth!`. Idempotent.

- [ ] **Step 1: Write the failing test**

`spec/workers/odoo_portal_sync_worker_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe OdooPortalSyncWorker do
  let(:org) { create(:organization) }
  let!(:conn) { ActsAsTenant.with_tenant(org) { create(:odoo_portal_connection, organization: org, status: "active") } }

  before do
    fake = instance_double(OdooPortal::Scraper)
    allow(OdooPortal::Scraper).to receive(:new).and_return(fake)
    allow(fake).to receive(:fetch_new).and_return([
      { "portal_lead_id" => "L1", "title" => "t", "html" => "<main>Contact: HASSAN\nEmail: h@x.com</main>" }
    ])
  end

  it "creates a customer and a processed PartnerPortalLead" do
    expect { described_class.new.perform(org.id) }
      .to change { ActsAsTenant.with_tenant(org) { Customer.count } }.by(1)
    lead = ActsAsTenant.with_tenant(org) { PartnerPortalLead.find_by(portal_lead_id: "L1") }
    expect(lead.status).to eq("processed")
    expect(lead.customer.email).to eq("h@x.com")
  end

  it "is idempotent on re-run (no duplicate customer)" do
    described_class.new.perform(org.id)
    expect { described_class.new.perform(org.id) }
      .not_to change { ActsAsTenant.with_tenant(org) { Customer.count } }
  end

  it "marks the connection needs_reauth when the session is expired" do
    allow_any_instance_of(OdooPortal::Scraper).to receive(:fetch_new)
      .and_raise(OdooPortal::BrowserRunner::SessionExpired)
    described_class.new.perform(org.id)
    expect(conn.reload.status).to eq("needs_reauth")
  end
end
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bundle exec rspec spec/workers/odoo_portal_sync_worker_spec.rb`
Expected: FAIL — `uninitialized constant OdooPortalSyncWorker`.

- [ ] **Step 3: Write the worker**

`app/workers/odoo_portal_sync_worker.rb`:
```ruby
# Pulls new portal leads for one org and upserts Customers. Runs on the root
# host (no tenant), so it re-establishes the org explicitly. Triggered by the
# email detector, the scheduled poll, or the manual "Sync now" button.
class OdooPortalSyncWorker
  include Sidekiq::Worker
  sidekiq_options queue: "followups", retry: 3

  def perform(organization_id)
    org  = ActsAsTenant.without_tenant { Organization.find_by(id: organization_id) }
    conn = org && OdooPortalConnection.for_organization(org)
    return unless conn&.active?

    ActsAsTenant.with_tenant(org) { sync(org, conn) }
  end

  private

  def sync(org, conn)
    known = PartnerPortalLead.where(organization: org).pluck(:portal_lead_id)
    new_leads = OdooPortal::Scraper.new(conn).fetch_new(known_ids: known)

    new_leads.each { |payload| ingest(org, payload) }
    conn.touch_synced!
  rescue OdooPortal::BrowserRunner::SessionExpired
    conn.mark_needs_reauth!
  rescue => e
    conn.mark_error!(e.message)
    raise
  end

  def ingest(org, payload)
    lead = PartnerPortalLead.create!(
      organization: org, portal_lead_id: payload["portal_lead_id"],
      status: "received", raw_payload: payload
    )
    attrs = OdooPortal::LeadParser.call(payload)
    customer = upsert_customer(org, attrs)
    lead.mark_processed!(customer)
  rescue ActiveRecord::RecordNotUnique
    nil # another run already ingested this portal_lead_id
  end

  def upsert_customer(org, attrs)
    Customer.find_or_initialize_by(organization: org, portal_lead_id: attrs[:portal_lead_id]).tap do |c|
      c.assign_attributes(attrs.except(:portal_lead_id).merge(status: c.status.presence || "Pending"))
      c.save!
    end
  end
end
```

- [ ] **Step 4: Run it, verify it passes**

Run: `bundle exec rspec spec/workers/odoo_portal_sync_worker_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/workers/odoo_portal_sync_worker.rb spec/workers/odoo_portal_sync_worker_spec.rb
git commit -m "feat(odoo-portal): OdooPortalSyncWorker ingests leads idempotently"
```

---

### Task 9: Email-trigger detector

**Files:**
- Create: `app/services/odoo_portal/email_trigger.rb`
- Modify: `app/workers/gmail_inbox_sync_worker.rb` (call the detector after sync)
- Test: `spec/services/odoo_portal/email_trigger_spec.rb`

**Interfaces:**
- Consumes: a `User` (whose org may have an active `OdooPortalConnection`), recent `Email`s.
- Produces: `OdooPortal::EmailTrigger.new(user).call` enqueues `OdooPortalSyncWorker` for the user's org **iff** the org has an active connection and a recent email matches its `watch_from`/`watch_subject`. Returns `true` if enqueued.

- [ ] **Step 1: Write the failing test**

`spec/services/odoo_portal/email_trigger_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe OdooPortal::EmailTrigger do
  let(:org)  { create(:organization) }
  let(:user) { create(:user) }

  before do
    create(:membership, user: user, organization: org)
    ActsAsTenant.with_tenant(org) do
      create(:odoo_portal_connection, organization: org, status: "active",
             watch_from: "odoo.com", watch_subject: "Lead")
    end
  end

  it "enqueues a sync when a matching email exists" do
    allow_any_instance_of(described_class).to receive(:recent_match?).and_return(true)
    expect { described_class.new(user).call }
      .to change(OdooPortalSyncWorker.jobs, :size).by(1)
  end

  it "does nothing without an active connection" do
    OdooPortalConnection.for_organization(org).update_columns(status: "needs_reauth")
    expect { described_class.new(user).call }.not_to change(OdooPortalSyncWorker.jobs, :size)
  end
end
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bundle exec rspec spec/services/odoo_portal/email_trigger_spec.rb`
Expected: FAIL — `uninitialized constant OdooPortal::EmailTrigger`.

- [ ] **Step 3: Write the detector**

`app/services/odoo_portal/email_trigger.rb`:
```ruby
module OdooPortal
  # After a Gmail sync, if the user's org watches the portal and a freshly
  # synced email looks like an Odoo lead notification, kick a portal fetch.
  class EmailTrigger
    LOOKBACK = 10.minutes

    def initialize(user)
      @user = user
    end

    def call
      org  = @user.organizations.find { |o| OdooPortalConnection.for_organization(o)&.active? }
      return false unless org

      conn = OdooPortalConnection.for_organization(org)
      return false unless recent_match?(org, conn)

      OdooPortalSyncWorker.perform_async(org.id)
      true
    end

    private

    def recent_match?(org, conn)
      scope = Email.where(organization_id: org.id).where("created_at > ?", LOOKBACK.ago)
      scope = scope.where("from_address ILIKE ?", "%#{conn.watch_from}%") if conn.watch_from.present?
      scope = scope.where("subject ILIKE ?", "%#{conn.watch_subject}%") if conn.watch_subject.present?
      scope.exists?
    end
  end
end
```

> Note: confirm `Email` column names (`from_address`, `subject`, `organization_id`) with `rails runner "puts Email.column_names"`; adjust the two ILIKE columns if they differ.

- [ ] **Step 4: Hook it into the Gmail worker**

In `app/workers/gmail_inbox_sync_worker.rb`, after `user.update_column(:last_gmail_sync_at, Time.current)`:
```ruby
    OdooPortal::EmailTrigger.new(user).call
```

- [ ] **Step 5: Run it, verify it passes**

Run: `bundle exec rspec spec/services/odoo_portal/email_trigger_spec.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/services/odoo_portal/email_trigger.rb app/workers/gmail_inbox_sync_worker.rb spec/services/odoo_portal/email_trigger_spec.rb
git commit -m "feat(odoo-portal): email-triggered portal fetch via gmail sync"
```

---

### Task 10: Scheduled poll + manual "Sync now"

**Files:**
- Modify: `config/sidekiq_scheduler.yml`
- Create: `app/workers/odoo_portal_poll_scheduler_worker.rb`
- Create: `app/controllers/odoo_portal/syncs_controller.rb`
- Modify: `config/routes.rb`
- Test: `spec/workers/odoo_portal_poll_scheduler_worker_spec.rb`, `spec/requests/odoo_portal/syncs_spec.rb`

**Interfaces:**
- Produces: `OdooPortalPollSchedulerWorker#perform` enqueues `OdooPortalSyncWorker` for every org with an active connection. `POST /odoo_portal/sync` enqueues a sync for the current tenant and redirects back.

- [ ] **Step 1: Write the scheduler-worker test**

`spec/workers/odoo_portal_poll_scheduler_worker_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe OdooPortalPollSchedulerWorker do
  it "enqueues a sync per active connection" do
    org1 = create(:organization); org2 = create(:organization)
    ActsAsTenant.with_tenant(org1) { create(:odoo_portal_connection, organization: org1, status: "active") }
    ActsAsTenant.with_tenant(org2) { create(:odoo_portal_connection, organization: org2, status: "needs_reauth") }
    expect { described_class.new.perform }.to change(OdooPortalSyncWorker.jobs, :size).by(1)
  end
end
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bundle exec rspec spec/workers/odoo_portal_poll_scheduler_worker_spec.rb`
Expected: FAIL — constant missing.

- [ ] **Step 3: Write the scheduler worker**

`app/workers/odoo_portal_poll_scheduler_worker.rb`:
```ruby
# Backstop: enqueue a fetch for every active connection (catches missed emails).
class OdooPortalPollSchedulerWorker
  include Sidekiq::Worker
  sidekiq_options queue: "default", retry: 1

  def perform
    ActsAsTenant.without_tenant do
      OdooPortalConnection.active.pluck(:organization_id).each do |org_id|
        OdooPortalSyncWorker.perform_async(org_id)
      end
    end
  end
end
```

- [ ] **Step 4: Schedule it**

Append to `config/sidekiq_scheduler.yml`:
```yaml
# Odoo partner-portal poll - backstop fetch every 2 hours
odoo_portal_poll:
  cron: "0 */2 * * *"
  class: OdooPortalPollSchedulerWorker
  queue: default
  description: "Enqueues a portal lead fetch for every active Odoo partner-portal connection"
```

- [ ] **Step 5: Run the worker test, verify it passes**

Run: `bundle exec rspec spec/workers/odoo_portal_poll_scheduler_worker_spec.rb`
Expected: PASS.

- [ ] **Step 6: Write the controller request test**

`spec/requests/odoo_portal/syncs_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe "Odoo portal manual sync", type: :request do
  it "enqueues a sync for the tenant and redirects" do
    org  = create(:organization)
    user = create(:user)
    create(:membership, user: user, organization: org, role: "admin")
    ActsAsTenant.with_tenant(org) { create(:odoo_portal_connection, organization: org, status: "active") }

    sign_in(user, org) # see spec/support sign-in helper used elsewhere
    expect { post "/odoo_portal/sync" }.to change(OdooPortalSyncWorker.jobs, :size).by(1)
    expect(response).to have_http_status(:redirect)
  end
end
```

> If a `sign_in` request helper does not already exist in `spec/support`, copy the auth-setup pattern from an existing file in `spec/requests/` (look at how those specs authenticate) and use it here.

- [ ] **Step 7: Run it, verify it fails**

Run: `bundle exec rspec spec/requests/odoo_portal/syncs_spec.rb`
Expected: FAIL — no route.

- [ ] **Step 8: Add controller + route**

`app/controllers/odoo_portal/syncs_controller.rb`:
```ruby
module OdooPortal
  class SyncsController < ApplicationController
    def create
      org = ActsAsTenant.current_tenant
      OdooPortalSyncWorker.perform_async(org.id) if org && OdooPortalConnection.for_organization(org)&.active?
      redirect_back fallback_location: "/settings/features", notice: "Lead sync started."
    end
  end
end
```

In `config/routes.rb`, add (near other feature routes):
```ruby
  namespace :odoo_portal do
    post "sync", to: "syncs#create"
  end
```

- [ ] **Step 9: Run it, verify it passes**

Run: `bundle exec rspec spec/requests/odoo_portal/syncs_spec.rb`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add app/workers/odoo_portal_poll_scheduler_worker.rb config/sidekiq_scheduler.yml app/controllers/odoo_portal/syncs_controller.rb config/routes.rb spec/workers/odoo_portal_poll_scheduler_worker_spec.rb spec/requests/odoo_portal/syncs_spec.rb
git commit -m "feat(odoo-portal): scheduled poll backstop + manual sync now"
```

---

### Task 11: Write-back event map + Customer callback

**Files:**
- Create: `app/services/odoo_portal/event_map.rb`
- Modify: `app/models/customer.rb` (after_update enqueue + guard)
- Test: `spec/services/odoo_portal/event_map_spec.rb`, `spec/models/customer_portal_pushback_spec.rb`

**Interfaces:**
- Produces: `OdooPortal::EventMap.action_for(customer) -> Hash|nil` e.g. `{ kind: "exception", note: "..." }` or `{ kind: "note", note: "..." }`. `Customer` after_update enqueues `OdooPortalPushWorker.perform_async(id)` only when (a) the customer has a `portal_lead_id`, (b) a mapped action exists, and (c) the change did not originate from an inbound sync (loop guard via `saved_change_to_status?` and not a fresh ingest).

- [ ] **Step 1: Write the event-map test**

`spec/services/odoo_portal/event_map_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe OdooPortal::EventMap do
  it "maps a disqualified customer to a portal exception" do
    c = build(:customer, status: "Disqualified")
    expect(described_class.action_for(c)).to include(kind: "exception")
  end

  it "maps contact established to a logged note" do
    c = build(:customer, status: "Contact Established")
    expect(described_class.action_for(c)).to include(kind: "note")
  end

  it "returns nil for unmapped statuses" do
    expect(described_class.action_for(build(:customer, status: "Pending"))).to be_nil
  end
end
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bundle exec rspec spec/services/odoo_portal/event_map_spec.rb`
Expected: FAIL — constant missing.

- [ ] **Step 3: Write the event map**

`app/services/odoo_portal/event_map.rb`:
```ruby
module OdooPortal
  # Translates a CRM Customer state into a portal write-back action. Kept tiny
  # and declarative; later this becomes per-org configurable (mirrors the Meta
  # status->event mapping).
  class EventMap
    MAP = {
      "Disqualified"        => { kind: "exception", note: "Disqualified in CRM" },
      "Contact Established" => { kind: "note", note: "Contact established (CRM)" }
    }.freeze

    def self.action_for(customer)
      MAP[customer.status]&.dup
    end
  end
end
```

- [ ] **Step 4: Run it, verify it passes**

Run: `bundle exec rspec spec/services/odoo_portal/event_map_spec.rb`
Expected: PASS.

- [ ] **Step 5: Write the Customer callback test**

`spec/models/customer_portal_pushback_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe "Customer -> portal push-back" do
  let(:org) { create(:organization) }

  around { |ex| ActsAsTenant.with_tenant(org) { ex.run } }

  it "enqueues a push when a portal customer's status maps to an action" do
    c = create(:customer, organization: org, portal_lead_id: "L1", status: "Pending")
    expect { c.update!(status: "Disqualified") }
      .to change(OdooPortalPushWorker.jobs, :size).by(1)
  end

  it "does not enqueue for customers without a portal_lead_id" do
    c = create(:customer, organization: org, portal_lead_id: nil, status: "Pending")
    expect { c.update!(status: "Disqualified") }
      .not_to change(OdooPortalPushWorker.jobs, :size)
  end
end
```

- [ ] **Step 6: Run it, verify it fails**

Run: `bundle exec rspec spec/models/customer_portal_pushback_spec.rb`
Expected: FAIL — `uninitialized constant OdooPortalPushWorker` (created next task) / no callback. To unblock this task, create an empty worker stub first:

`app/workers/odoo_portal_push_worker.rb`:
```ruby
class OdooPortalPushWorker
  include Sidekiq::Worker
  sidekiq_options queue: "followups", retry: 3
  def perform(_customer_id); end # real body in Task 12
end
```

- [ ] **Step 7: Add the callback to `Customer`**

In `app/models/customer.rb`, add:
```ruby
  after_update :enqueue_portal_pushback, if: :portal_pushback_needed?

  private

  def portal_pushback_needed?
    portal_lead_id.present? && saved_change_to_status? &&
      OdooPortal::EventMap.action_for(self).present?
  end

  def enqueue_portal_pushback
    OdooPortalPushWorker.perform_async(id)
  end
```

> Loop guard: the inbound `OdooPortalSyncWorker#upsert_customer` sets status only to `"Pending"` for new rows and does not overwrite an existing status, so re-ingesting our own pushed change does not re-fire this callback. Verified by Task 8's idempotency test.

- [ ] **Step 8: Run it, verify it passes**

Run: `bundle exec rspec spec/models/customer_portal_pushback_spec.rb`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add app/services/odoo_portal/event_map.rb app/models/customer.rb app/workers/odoo_portal_push_worker.rb spec/services/odoo_portal/event_map_spec.rb spec/models/customer_portal_pushback_spec.rb
git commit -m "feat(odoo-portal): write-back event map + customer push callback"
```

---

### Task 12: `OdooPortal::Writer` + `OdooPortalPushWorker` body

**Files:**
- Create: `app/services/odoo_portal/writer.rb`
- Modify: `app/workers/odoo_portal_push_worker.rb`
- Modify: `lib/odoo_portal/portal_agent.js` (`write_action` click-paths)
- Test: `spec/services/odoo_portal/writer_spec.rb`, `spec/workers/odoo_portal_push_worker_spec.rb`

**Interfaces:**
- Consumes: `OdooPortal::BrowserRunner`, `OdooPortal::EventMap`, `PartnerPortalLead` (to resolve the lead URL).
- Produces: `OdooPortal::Writer.new(connection).perform(portal_lead_id:, action:)` calls the agent `write_action`. `OdooPortalPushWorker#perform(customer_id)` resolves the org/connection/action and calls the writer; stamps `portal_last_pushed_at`.

- [ ] **Step 1: Write the writer test**

`spec/services/odoo_portal/writer_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe OdooPortal::Writer do
  let(:conn) { build(:odoo_portal_connection) }
  let(:runner) { instance_double(OdooPortal::BrowserRunner) }

  it "invokes the agent write_action with the lead url + action" do
    expect(runner).to receive(:run).with("write_action", hash_including("kind" => "exception"))
    described_class.new(conn, runner: runner).perform(url: "u1", action: { kind: "exception", note: "x" })
  end
end
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bundle exec rspec spec/services/odoo_portal/writer_spec.rb`
Expected: FAIL — constant missing.

- [ ] **Step 3: Write the writer**

`app/services/odoo_portal/writer.rb`:
```ruby
module OdooPortal
  class Writer
    def initialize(connection, runner: BrowserRunner.new(connection))
      @runner = runner
    end

    def perform(url:, action:)
      @runner.run("write_action", "url" => url, "kind" => action[:kind], "note" => action[:note])
    end
  end
end
```

- [ ] **Step 4: Run it, verify it passes**

Run: `bundle exec rspec spec/services/odoo_portal/writer_spec.rb`
Expected: PASS.

- [ ] **Step 5: Write the push-worker test**

`spec/workers/odoo_portal_push_worker_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe OdooPortalPushWorker do
  let(:org) { create(:organization) }

  it "performs the mapped portal action and stamps the customer" do
    conn = ActsAsTenant.with_tenant(org) { create(:odoo_portal_connection, organization: org, status: "active") }
    customer = ActsAsTenant.with_tenant(org) { create(:customer, organization: org, portal_lead_id: "L1", status: "Disqualified") }
    ActsAsTenant.with_tenant(org) { create(:partner_portal_lead, organization: org, portal_lead_id: "L1", raw_payload: { "url" => "u1" }, customer: customer) }

    writer = instance_double(OdooPortal::Writer)
    allow(OdooPortal::Writer).to receive(:new).and_return(writer)
    expect(writer).to receive(:perform).with(url: "u1", action: hash_including(kind: "exception"))

    described_class.new.perform(customer.id)
    expect(customer.reload.portal_last_pushed_at).to be_present
  end
end
```

- [ ] **Step 6: Run it, verify it fails**

Run: `bundle exec rspec spec/workers/odoo_portal_push_worker_spec.rb`
Expected: FAIL — worker stub does nothing.

- [ ] **Step 7: Write the worker body**

Replace `app/workers/odoo_portal_push_worker.rb`:
```ruby
# Pushes a CRM status change into the partner portal (note / exception / stage)
# via the saved session. Resolves the lead URL from the PartnerPortalLead row.
class OdooPortalPushWorker
  include Sidekiq::Worker
  sidekiq_options queue: "followups", retry: 3

  def perform(customer_id)
    customer = ActsAsTenant.without_tenant { Customer.find_by(id: customer_id) }
    return unless customer&.portal_lead_id.present?

    org  = ActsAsTenant.without_tenant { customer.organization }
    conn = OdooPortalConnection.for_organization(org)
    return unless conn&.active?

    ActsAsTenant.with_tenant(org) do
      action = OdooPortal::EventMap.action_for(customer)
      return unless action

      lead = PartnerPortalLead.find_by(organization: org, portal_lead_id: customer.portal_lead_id)
      url  = lead&.raw_payload.to_h["url"]
      return unless url

      OdooPortal::Writer.new(conn).perform(url: url, action: action)
      customer.update_columns(portal_last_pushed_at: Time.current)
    end
  rescue OdooPortal::BrowserRunner::SessionExpired
    OdooPortalConnection.for_organization(org)&.mark_needs_reauth!
  end
end
```

- [ ] **Step 8: Finalize the agent `write_action` click-paths**

In `lib/odoo_portal/portal_agent.js`, replace the `write_action` case body with the real portal interactions (captured alongside Task 6), e.g. for a note: focus the message box, type `payload.note`, click Send; for exception: open the stage/feedback control and select Exception. Keep the JSON return `{ performed: payload.kind }`.

- [ ] **Step 9: Run the worker test, verify it passes**

Run: `bundle exec rspec spec/workers/odoo_portal_push_worker_spec.rb`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add app/services/odoo_portal/writer.rb app/workers/odoo_portal_push_worker.rb lib/odoo_portal/portal_agent.js spec/services/odoo_portal/writer_spec.rb spec/workers/odoo_portal_push_worker_spec.rb
git commit -m "feat(odoo-portal): write-back via Writer + OdooPortalPushWorker"
```

---

### Task 13: Settings UI — connect, health, re-auth, mapping

**Files:**
- Create: `app/controllers/odoo_portal/connections_controller.rb`
- Create: `app/views/odoo_portal/connections/show.html.erb`
- Modify: `app/views/settings/_branding.html.erb` or the features settings view (add an "Odoo Partner Portal" card)
- Modify: `config/routes.rb`
- Test: `spec/requests/odoo_portal/connections_spec.rb`

**Interfaces:**
- Produces: `GET /odoo_portal/connection` (status + Sync now + re-auth), `POST /odoo_portal/connection` (save base_url + watch rules + paste/upload captured cookie jar → status `active`), `DELETE /odoo_portal/connection` (disconnect). Admin-only (Pundit, like other feature settings).

- [ ] **Step 1: Write the request test**

`spec/requests/odoo_portal/connections_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe "Odoo portal connection settings", type: :request do
  let(:org)  { create(:organization) }
  let(:user) { create(:user) }

  before do
    create(:membership, user: user, organization: org, role: "admin")
    sign_in(user, org) # reuse the existing request sign-in helper
  end

  it "saves a connection and marks it active" do
    cookies_json = [{ "name" => "session_id", "value" => "z" }].to_json
    post "/odoo_portal/connection", params: {
      odoo_portal_connection: { base_url: "https://www.odoo.com", watch_from: "odoo.com", watch_subject: "Lead", session_cookies: cookies_json }
    }
    conn = ActsAsTenant.with_tenant(org) { OdooPortalConnection.for_organization(org) }
    expect(conn.status).to eq("active")
    expect(conn.cookies.first["value"]).to eq("z")
  end
end
```

- [ ] **Step 2: Run it, verify it fails**

Run: `bundle exec rspec spec/requests/odoo_portal/connections_spec.rb`
Expected: FAIL — no route.

- [ ] **Step 3: Add routes**

In `config/routes.rb`, extend the namespace from Task 10:
```ruby
  namespace :odoo_portal do
    post "sync", to: "syncs#create"
    resource :connection, only: [:show, :create, :destroy], controller: "connections"
  end
```

- [ ] **Step 4: Write the controller**

`app/controllers/odoo_portal/connections_controller.rb`:
```ruby
module OdooPortal
  class ConnectionsController < ApplicationController
    before_action :require_admin

    def show
      @connection = current_connection
    end

    def create
      conn = current_connection || OdooPortalConnection.new(organization: ActsAsTenant.current_tenant)
      conn.assign_attributes(connection_params)
      conn.status = conn.session_cookies.present? ? "active" : "needs_reauth"
      conn.save!
      redirect_to "/settings/features", notice: "Odoo partner portal connected."
    end

    def destroy
      current_connection&.destroy
      redirect_to "/settings/features", notice: "Odoo partner portal disconnected."
    end

    private

    def current_connection
      OdooPortalConnection.for_organization(ActsAsTenant.current_tenant)
    end

    def connection_params
      params.require(:odoo_portal_connection).permit(:base_url, :watch_from, :watch_subject, :session_cookies)
    end

    def require_admin
      head :forbidden unless current_user&.admin? # match the app's existing admin check
    end
  end
end
```

> Replace `current_user&.admin?` with the app's actual admin predicate (check how `meta_lead_ads/connections_controller.rb` guards admin and copy that exact guard).

- [ ] **Step 5: Write a minimal view**

`app/views/odoo_portal/connections/show.html.erb`:
```erb
<section class="relay-card">
  <h2>Odoo Partner Portal</h2>
  <% if @connection&.active? %>
    <p>Status: Connected · Last synced: <%= @connection.last_synced_at&.to_fs(:short) || "never" %></p>
    <%= button_to "Sync now", "/odoo_portal/sync", method: :post %>
    <%= button_to "Disconnect", "/odoo_portal/connection", method: :delete %>
  <% else %>
    <p>Status: <%= @connection&.status || "not connected" %>. Paste your captured session cookies to connect.</p>
    <%= form_with url: "/odoo_portal/connection", method: :post do |f| %>
      <%= f.fields_for :odoo_portal_connection do |c| %>
        <%= c.text_field :base_url, value: "https://www.odoo.com" %>
        <%= c.text_field :watch_from, placeholder: "notification sender (e.g. odoo.com)" %>
        <%= c.text_field :watch_subject, placeholder: "subject contains (e.g. Lead)" %>
        <%= c.text_area :session_cookies, placeholder: "captured cookie JSON" %>
      <% end %>
      <%= f.submit "Connect" %>
    <% end %>
  <% end %>
</section>
```

- [ ] **Step 6: Link it from the features settings page**

In the features settings view (where Meta Lead Ads renders its card), add a link/card to `"/odoo_portal/connection"` guarded by `org.feature_enabled?(:odoo_partner_portal)`.

- [ ] **Step 7: Run it, verify it passes**

Run: `bundle exec rspec spec/requests/odoo_portal/connections_spec.rb`
Expected: PASS.

- [ ] **Step 8: Run the full connector suite**

Run: `bundle exec rspec spec/models/odoo_portal_connection_spec.rb spec/models/partner_portal_lead_spec.rb spec/services/odoo_portal spec/workers/odoo_portal_sync_worker_spec.rb spec/workers/odoo_portal_push_worker_spec.rb spec/requests/odoo_portal`
Expected: all PASS.

- [ ] **Step 9: Commit**

```bash
git add app/controllers/odoo_portal/connections_controller.rb app/views/odoo_portal config/routes.rb spec/requests/odoo_portal/connections_spec.rb
git commit -m "feat(odoo-portal): self-service connect/health/sync settings UI"
```

---

## Self-Review

**Spec coverage:**
- No-API rationale → Task 0/6 (browser agent). ✓
- Per-org feature toggle → Task 1. ✓
- Saved-session login (password & Google) → Task 2 (encrypted cookies) + Task 13 (paste captured cookies). ✓
- Ingest flow (PartnerPortalLead → Customer, idempotent) → Tasks 3,4,5,7,8. ✓
- Email-triggered fetch → Task 9. ✓
- Scheduled poll + manual → Task 10. ✓
- Write-back (note/exception/stage) → Tasks 11,12. ✓
- Loop prevention → Task 8 (no status overwrite) + Task 11 (guard) note. ✓
- Multi-tenant/self-service → every model `acts_as_tenant`; Task 13 connect UI. ✓
- Error handling (session expiry, scrape failure, dedupe) → Tasks 2,8,12. ✓
- Security (encrypted at rest) → Task 2. ✓

**Placeholder scan:** the two "confirm column/guard against existing code" notes (Email columns in Task 9; admin predicate + sign_in helper in Tasks 10/13) are explicit verification steps against real code, with the exact command to check — not deferred work. The live-selector capture (Task 6 Step 5) is a concrete, runnable capture step, not a TODO.

**Type consistency:** `BrowserRunner#run(action, payload={})`, `Scraper#fetch_new(known_ids:)`, `LeadParser.call(payload)->Hash`, `EventMap.action_for(customer)->Hash|nil`, `Writer#perform(url:, action:)`, `OdooPortalConnection.for_organization`, `PartnerPortalLead#mark_processed!(customer)` — names/signatures are used consistently across tasks.

## Known follow-ups (not in this plan)
- Per-org editable field map + event map UI (currently constants).
- Hosting the one-time interactive login capture in-app (this plan accepts a pasted/uploaded cookie jar; a guided remote-browser capture is a future enhancement).
- Extraction into `engines/odoo_portal` once stable (host-app placement here matches the live Meta-inbound pattern).
