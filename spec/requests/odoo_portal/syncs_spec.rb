require "rails_helper"

RSpec.describe "Odoo portal manual sync", :sidekiq_fake, type: :request do
  let(:org)  { create(:organization, subdomain: "odoo-sync-test") }
  let(:host) { "#{org.subdomain}.example.com" }
  let(:user) { create(:user, confirmed_at: Time.current) }

  before do
    host! host
    ActsAsTenant.with_tenant(org) do
      create(:membership, :admin, user: user, organization: org)
      create(:odoo_portal_connection, organization: org, status: "active")
    end
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  it "enqueues a sync for the tenant and redirects" do
    expect { post "/odoo_portal/sync" }.to change(OdooPortalSyncWorker.jobs, :size).by(1)
    expect(response).to have_http_status(:redirect)
  end
end
