require "rails_helper"

RSpec.describe OdooPortalSyncWorker do
  let(:org) { create(:organization) }
  let!(:conn) { ActsAsTenant.with_tenant(org) { create(:odoo_portal_connection, organization: org, status: "active") } }
  let(:scraper) { instance_double(OdooPortal::Scraper) }

  before do
    allow(OdooPortal::Scraper).to receive(:new).and_return(scraper)
    allow(scraper).to receive(:fetch_new).and_return([
      { "portal_lead_id" => "L1", "title" => "Lead - HASSAN (animeworldpak) Registration",
        "contact_name" => "HASSAN", "email" => "h@x.com", "phone" => "+92 300 0000000",
        "html" => "<main></main>" }
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
    allow(scraper).to receive(:fetch_new)
      .and_raise(OdooPortal::BrowserRunner::SessionExpired)
    described_class.new.perform(org.id)
    expect(conn.reload.status).to eq("needs_reauth")
  end

  it "isolates a single bad lead: marks it failed but keeps connection active" do
    allow(OdooPortal::LeadParser).to receive(:call)
      .and_raise(ActiveRecord::RecordInvalid.new(Customer.new))
    described_class.new.perform(org.id)
    lead = ActsAsTenant.with_tenant(org) { PartnerPortalLead.find_by(portal_lead_id: "L1") }
    expect(lead.status).to eq("failed")
    expect(conn.reload.status).to eq("active")
  end
end
