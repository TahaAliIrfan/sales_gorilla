require "rails_helper"

# Phase 7 Outreach smoke + scoping coverage. Drives the real controller + views
# (campaigns / audiences / templates tabs) through a tenant subdomain request,
# verifying the segbar counts, audience cards, the admin-only templates tab, and
# Pundit scoping so an associate only sees their own campaigns and groups.
RSpec.describe "Relay Outreach", type: :request do
  let(:org)  { create(:organization, subdomain: "outreach-test") }
  let(:host) { "#{org.subdomain}.example.com" }

  def as_user(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  # Roles aren't seeded in the test env (see config/initializers/role_setup.rb),
  # so seed them here — assign_role is a no-op without the Role rows.
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

    it "renders the campaigns tab with a per-recipient segbar" do
      ActsAsTenant.with_tenant(org) do
        campaign = Campaign.create!(name: "June re-engagement", message: "Hi {{name}}",
                                    status: "in_progress", user: admin, organization: org)
        c1 = create(:customer, organization: org, user: admin)
        c2 = create(:customer, organization: org, user: admin)
        campaign.campaign_executions.create!(customer: c1, status: "completed", scheduled_at: 1.hour.ago)
        campaign.campaign_executions.create!(customer: c2, status: "failed", scheduled_at: 1.hour.ago)
      end

      get outreach_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("June re-engagement")
      expect(response.body).to include("segbar")
      expect(response.body).to include("Sending") # in_progress status pill
      expect(response.body).not_to include("ic--missing")
    end

    it "renders the audiences tab with member counts" do
      ActsAsTenant.with_tenant(org) do
        group = CustomerGroup.create!(name: "Warm leads", user: admin, organization: org)
        group.add_customer(create(:customer, organization: org, user: admin))
      end

      get outreach_path(tab: "audiences")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Warm leads")
      expect(response.body).to include("contacts")
    end

    it "renders the admin-only templates tab" do
      ActsAsTenant.with_tenant(org) do
        WhatsappTemplate.create!(content_sid: "HX1", friendly_name: "Welcome",
                                 approval_status: "approved", language: "en",
                                 body: "Hi {{1}}, welcome!", organization: org)
      end

      get outreach_path(tab: "templates")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Welcome")
      expect(response.body).to include("Sync templates")
      expect(response.body).to include("Approved")
    end

    it "shows the empty campaigns state" do
      get outreach_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No campaigns yet")
    end
  end

  describe "as an associate" do
    let(:associate) { create(:user) }
    let(:other)     { create(:user) }

    before do
      ActsAsTenant.with_tenant(org) do
        create(:membership, :member, user: associate, organization: org)
        associate.assign_role(:associate)
        create(:membership, :member, user: other, organization: org)
        other.assign_role(:associate)
      end
      as_user(associate)
    end

    it "scopes campaigns to the associate and hides the templates tab" do
      ActsAsTenant.with_tenant(org) do
        Campaign.create!(name: "Mine", message: "x", status: "draft", user: associate, organization: org)
        Campaign.create!(name: "Theirs", message: "x", status: "draft", user: other, organization: org)
      end

      get outreach_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Mine")
      expect(response.body).not_to include("Theirs")
      # Templates tab is admin-only — its link should not be rendered.
      expect(response.body).not_to include("tab=templates")
    end

    it "redirects the templates tab back to campaigns for non-admins" do
      get outreach_path(tab: "templates")
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Sync templates")
    end
  end
end
