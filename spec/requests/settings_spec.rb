require "rails_helper"

# Phase 10 Settings workspace smoke + gating coverage. Drives the real
# SettingsController + Settings::FeaturesController + Relay settings views
# through a tenant subdomain request, verifying the tab bar, profile/branding/
# team/integrations/features panels, admin gating (associates can't see
# branding/team/features), the branding update flow posting to the right path,
# and the absence of missing icons.
RSpec.describe "Relay Settings", type: :request do
  let(:org)  { create(:organization, subdomain: "settings-test") }
  let(:host) { "#{org.subdomain}.example.com" }

  def as_user(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  before do
    Role.seed_default_roles
    host! host
  end

  describe "as an admin" do
    let(:admin) { create(:user) }

    before do
      ActsAsTenant.with_tenant(org) do
        create(:membership, :admin, user: admin, organization: org)
        admin.assign_role(:admin)
      end
      as_user(admin)
    end

    it "renders the profile tab by default with the full tab bar" do
      get settings_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Settings")
      expect(response.body).to include("Profile")
      expect(response.body).to include("Branding &amp; theme")
      expect(response.body).to include("Team &amp; roles")
      expect(response.body).to include("Integrations")
      # admin sees the Features tab link
      expect(response.body).to include(settings_features_path)
      expect(response.body).not_to include("ic--missing")
    end

    it "renders the branding tab with a live-preview form posting to the branding path" do
      get settings_path(tab: "branding")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Live preview")
      expect(response.body).to include("relay--branding-preview")
      # form targets the existing BrandingController#update endpoint
      expect(response.body).to include(%(action="#{branding_path}"))
      expect(response.body).not_to include("ic--missing")
    end

    it "renders the team tab listing users with role controls" do
      ActsAsTenant.with_tenant(org) do
        other = create(:user, name: "Dana Okafor")
        create(:membership, :member, user: other, organization: org)
        other.assign_role(:associate)
      end

      get settings_path(tab: "team")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Team &amp; roles")
      expect(response.body).to include("Dana Okafor")
      expect(response.body).to include("relay--user-admin")
      expect(response.body).not_to include("ic--missing")
    end

    it "renders the integrations tab" do
      get settings_path(tab: "integrations")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Integrations")
      expect(response.body).to include("Google Calendar")
      expect(response.body).not_to include("ic--missing")
    end

    it "renders the features page with DS classes and the same tab bar" do
      get settings_features_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Calling")
      # DS, not Tailwind: the restyled card uses the sect + rl-switch components
      expect(response.body).to include("rl-switch")
      expect(response.body).to include("rl-select")
      # same workspace tab bar on top
      expect(response.body).to include("rl-tabs")
      expect(response.body).to include(settings_path(tab: "profile"))
      expect(response.body).not_to include("ic--missing")
    end

    it "keeps the branding update flow intact" do
      patch branding_path, params: { organization: { name: "Acme", primary_color: "#123456" } }
      expect(response).to redirect_to(settings_path(tab: "branding"))
      expect(org.reload.name).to eq("Acme")
      expect(org.primary_color).to eq("#123456")
    end
  end

  describe "as an associate" do
    let(:associate) { create(:user) }

    before do
      ActsAsTenant.with_tenant(org) do
        create(:membership, :member, user: associate, organization: org)
        associate.assign_role(:associate)
      end
      as_user(associate)
    end

    it "hides the admin-only tabs" do
      get settings_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Profile")
      expect(response.body).to include("Integrations")
      expect(response.body).not_to include("Branding &amp; theme")
      expect(response.body).not_to include("Team &amp; roles")
      expect(response.body).not_to include(settings_features_path)
    end

    it "falls back to profile when requesting the branding tab" do
      get settings_path(tab: "branding")
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Live preview")
    end
  end
end
