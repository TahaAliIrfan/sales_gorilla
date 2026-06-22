require "rails_helper"

RSpec.describe EnrichLeadWorker, :sidekiq_fake do
  let(:org) { create(:organization) }
  let(:customer) { ActsAsTenant.with_tenant(org) { create(:customer, organization: org) } }

  before do
    allow(LeadEnrichmentService).to receive(:call).and_return(
      summary: "A real exporter", industry: "Manufacturing", legitimacy_score: 90, is_junk: false
    )
  end

  it "writes the enrichment fields and stamps enriched_at" do
    described_class.new.perform(customer.id)
    c = ActsAsTenant.with_tenant(org) { Customer.find(customer.id) }
    expect(c).to have_attributes(enrichment_summary: "A real exporter", industry: "Manufacturing",
                                 legitimacy_score: 90, lead_is_junk: false)
    expect(c.enriched_at).to be_present
  end

  it "enqueues the call-script worker after enriching" do
    expect { described_class.new.perform(customer.id) }
      .to change(GenerateCallScriptWorker.jobs, :size).by(1)
  end

  it "does nothing for a missing customer" do
    expect { described_class.new.perform(-1) }.not_to raise_error
  end
end
