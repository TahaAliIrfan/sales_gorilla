require "rails_helper"

RSpec.describe OdooPortalPushWorker do
  let(:org) { create(:organization) }

  it "performs the mapped portal action and stamps the customer" do
    conn = ActsAsTenant.with_tenant(org) { create(:odoo_portal_connection, organization: org, status: "active") }
    customer = ActsAsTenant.with_tenant(org) { create(:customer, organization: org, portal_lead_id: "L1", status: "Not Interested") }
    ActsAsTenant.with_tenant(org) { create(:partner_portal_lead, organization: org, portal_lead_id: "L1", raw_payload: { "url" => "u1" }, customer: customer) }

    writer = instance_double(OdooPortal::Writer)
    allow(OdooPortal::Writer).to receive(:new).and_return(writer)
    expect(writer).to receive(:perform).with(url: "u1", action: hash_including(kind: "exception"))

    described_class.new.perform(customer.id)
    expect(customer.reload.portal_last_pushed_at).to be_present
  end
end
