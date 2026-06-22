require "rails_helper"

RSpec.describe "Customer -> portal push-back", :sidekiq_fake do
  let(:org) { create(:organization) }

  around { |ex| ActsAsTenant.with_tenant(org) { ex.run } }

  it "enqueues a push when a portal customer's status maps to an action" do
    c = create(:customer, organization: org, portal_lead_id: "L1", status: "Pending")
    expect { c.update!(status: "Not Interested") }
      .to change(OdooPortalPushWorker.jobs, :size).by(1)
  end

  it "does not enqueue for customers without a portal_lead_id" do
    c = create(:customer, organization: org, portal_lead_id: nil, status: "Pending")
    expect { c.update!(status: "Not Interested") }
      .not_to change(OdooPortalPushWorker.jobs, :size)
  end
end
