require "rails_helper"

RSpec.describe OdooPortalPollSchedulerWorker, :sidekiq_fake do
  it "enqueues a sync per active connection" do
    org1 = create(:organization); org2 = create(:organization)
    ActsAsTenant.with_tenant(org1) { create(:odoo_portal_connection, organization: org1, status: "active") }
    ActsAsTenant.with_tenant(org2) { create(:odoo_portal_connection, organization: org2, status: "needs_reauth") }
    expect { described_class.new.perform }.to change(OdooPortalSyncWorker.jobs, :size).by(1)
  end
end
