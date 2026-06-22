require "rails_helper"

RSpec.describe "Re-run lead intelligence", :sidekiq_fake, type: :request do
  let(:org)  { create(:organization, subdomain: "enrich-test") }
  let(:host) { "#{org.subdomain}.example.com" }
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:customer) { ActsAsTenant.with_tenant(org) { create(:customer, organization: org, company: "Nurikon") } }

  before do
    host! host
    ActsAsTenant.with_tenant(org) { create(:membership, :admin, user: user, organization: org) }
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    customer # force eager creation so after_create job is already enqueued before the expect block
  end

  it "enqueues enrichment for the customer and redirects" do
    # the after_create already enqueued one; assert the manual action adds another
    expect { post enrich_customer_path(customer) }
      .to change(EnrichLeadWorker.jobs, :size).by(1)
    expect(response).to have_http_status(:redirect)
  end
end
