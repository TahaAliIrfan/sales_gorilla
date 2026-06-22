require "rails_helper"

RSpec.describe CallScriptService do
  let(:org) { create(:organization) }
  let(:customer) { ActsAsTenant.with_tenant(org) { create(:customer, organization: org, name: "Faraz", company: "Nurikon", industry: "Manufacturing", enrichment_summary: "Surgical instrument exporter") } }
  let(:client) { instance_double(Ai::Client) }

  before { allow(Ai::Client).to receive(:for_organization).with(org).and_return(client) }

  it "asks the AI for a Roman-Urdu script and returns it" do
    expect(client).to receive(:complete) do |system:, prompt:|
      expect(system).to match(/Roman Urdu/i)
      expect(prompt).to include("Nurikon")
      expect(prompt).to include("Surgical instrument exporter")
      "Assalam-o-Alaikum Faraz sahab, main Arham..."
    end
    expect(described_class.call(customer)).to start_with("Assalam-o-Alaikum")
  end
end
