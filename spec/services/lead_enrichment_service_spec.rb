require "rails_helper"

RSpec.describe LeadEnrichmentService do
  let(:org) { create(:organization) }
  let(:customer) { ActsAsTenant.with_tenant(org) { create(:customer, organization: org, company: "Nurikon", name: "Faraz") } }
  let(:client) { instance_double(Ai::Client) }

  before { allow(Ai::Client).to receive(:for_organization).with(org).and_return(client) }

  it "parses the AI research JSON into structured fields" do
    allow(client).to receive(:research).and_return(
      %(Here is my research:\n{"summary":"Surgical instrument exporter","industry":"Manufacturing","legitimacy_score":85,"is_junk":false}\nThanks)
    )
    result = described_class.call(customer)
    expect(result).to include(summary: "Surgical instrument exporter", industry: "Manufacturing", legitimacy_score: 85, is_junk: false)
  end

  it "falls back gracefully when the AI returns no JSON" do
    allow(client).to receive(:research).and_return("no json here, just prose")
    result = described_class.call(customer)
    expect(result[:summary]).to be_present
    expect(result[:legitimacy_score]).to be_nil
  end
end
