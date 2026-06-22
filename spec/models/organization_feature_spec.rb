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
