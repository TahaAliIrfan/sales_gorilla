require "rails_helper"

RSpec.describe "Customer auto-enrichment on create", :sidekiq_fake do
  let(:org) { create(:organization) }
  around { |ex| ActsAsTenant.with_tenant(org) { ex.run } }

  it "enqueues enrichment when the lead has a company" do
    expect { create(:customer, organization: org, company: "Nurikon") }
      .to change(EnrichLeadWorker.jobs, :size).by(1)
  end

  it "enqueues enrichment when the lead has an idea description" do
    expect { create(:customer, organization: org, company: nil, idea_description: "wants POS") }
      .to change(EnrichLeadWorker.jobs, :size).by(1)
  end

  it "does not enqueue for an empty stub customer" do
    expect { create(:customer, organization: org, company: nil, idea_description: nil) }
      .not_to change(EnrichLeadWorker.jobs, :size)
  end
end
