require "rails_helper"

RSpec.describe Customer do
  it "persists portal_lead_id" do
    org = create(:organization)
    c = ActsAsTenant.with_tenant(org) { create(:customer, organization: org, portal_lead_id: "L9") }
    expect(c.reload.portal_lead_id).to eq("L9")
  end
end
