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

  it "accepts the ai feature with a claude provider" do
    org = create(:organization)
    expect(org.features.build(key: "ai", provider: "claude", enabled: true)).to be_valid
  end

  it "rejects an unsupported provider for ai" do
    org = create(:organization)
    f = org.features.build(key: "ai", provider: "twilio")
    expect(f).not_to be_valid
    expect(f.errors[:provider]).to be_present
  end
end
