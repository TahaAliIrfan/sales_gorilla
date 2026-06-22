require "rails_helper"

RSpec.describe OdooPortal::EmailTrigger, :sidekiq_fake do
  let(:org)  { create(:organization) }
  let(:user) { create(:user, confirmed_at: Time.current) }

  before do
    create(:membership, user: user, organization: org)
    ActsAsTenant.with_tenant(org) do
      create(:odoo_portal_connection, organization: org, status: "active",
             watch_from: "odoo.com", watch_subject: "Lead")
    end
  end

  it "enqueues a sync when a matching email exists" do
    allow_any_instance_of(described_class).to receive(:recent_match?).and_return(true)
    expect { described_class.new(user).call }
      .to change(OdooPortalSyncWorker.jobs, :size).by(1)
  end

  it "does nothing without an active connection" do
    OdooPortalConnection.for_organization(org).update_columns(status: "needs_reauth")
    expect { described_class.new(user).call }.not_to change(OdooPortalSyncWorker.jobs, :size)
  end
end
