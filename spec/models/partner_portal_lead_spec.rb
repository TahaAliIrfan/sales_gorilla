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
