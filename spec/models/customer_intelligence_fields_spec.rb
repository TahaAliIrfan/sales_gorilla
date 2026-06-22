require "rails_helper"

RSpec.describe Customer do
  it "persists the intelligence fields" do
    org = create(:organization)
    c = ActsAsTenant.with_tenant(org) do
      create(:customer, organization: org, industry: "Manufacturing", legitimacy_score: 80,
             lead_is_junk: false, enrichment_summary: "x", call_script: "script")
    end
    expect(c.reload).to have_attributes(industry: "Manufacturing", legitimacy_score: 80, lead_is_junk: false)
  end
end
