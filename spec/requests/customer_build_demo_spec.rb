require "rails_helper"

RSpec.describe "Build demo", :sidekiq_fake, type: :request do
  let(:org)  { create(:organization, subdomain: "demo-build-test") }
  let(:host) { "#{org.subdomain}.example.com" }
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:customer) { ActsAsTenant.with_tenant(org) { create(:customer, organization: org, company: "Nurikon") } }

  before do
    host! host
    ActsAsTenant.with_tenant(org) { create(:membership, :admin, user: user, organization: org) }
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  it "enqueues BuildDemoWorker and redirects" do
    expect { post build_demo_customer_path(customer) }
      .to change(BuildDemoWorker.jobs, :size).by(1)
    expect(response).to have_http_status(:redirect)
  end
end
