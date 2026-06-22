require "rails_helper"

RSpec.describe "Per-org feature config", type: :request do
  let(:org)  { create(:organization, subdomain: "feat-cfg") }
  let(:user) { create(:user, confirmed_at: Time.current) }

  before do
    host! "#{org.subdomain}.example.com"
    ActsAsTenant.with_tenant(org) { create(:membership, :admin, user: user, organization: org) }
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  it "saves an org-specific AI api_key into the ai feature settings" do
    feature = ActsAsTenant.with_tenant(org) { org.features.create!(key: "ai", provider: "claude", enabled: true, settings: {}) }
    patch settings_feature_path(key: "ai"), params: {
      organization_feature: { enabled: "1", provider: "claude", settings: { api_key: "sk-org-123", model: "claude-opus-4-8" } }
    }
    expect(feature.reload.settings_for("api_key")).to eq("sk-org-123")
    expect(feature.settings_for("model")).to eq("claude-opus-4-8")
  end
end
