require "rails_helper"

# Phase 8 Insights smoke + scoping coverage. Drives the real ReportsController
# + Relay Insights views through a tenant subdomain request, verifying the KPI
# tiles, conversion funnel, per-rep table (admins/managers only), the
# associate-scoped #my_reports variant, the date-range presets, and the absence
# of missing icons.
RSpec.describe "Relay Insights", type: :request do
  let(:org)  { create(:organization, subdomain: "insights-test") }
  let(:host) { "#{org.subdomain}.example.com" }

  def as_user(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  # Roles aren't seeded in the test env, so seed them here.
  before do
    Role.seed_default_roles
    host! host
  end

  # Build a billable call recording for a rep on a given date.
  def make_call(user:, customer:, on:, sid:)
    Recording.create!(user: user, customer: customer, organization: org,
                      sid: sid, call_sid: "C-#{sid}", duration: 130,
                      date: on)
  end

  # Build a deal in a known terminal state. Needs a pipeline + stage.
  def make_deal(user:, customer:, status:, amount:, closing_date:, stage:)
    Deal.create!(user: user, customer: customer, organization: org,
                 title: "Deal #{status} #{amount}", amount: amount,
                 status: status, closing_date: closing_date, deal_stage: stage)
  end

  def build_stage(owner)
    pipeline = Pipeline.create!(name: "Sales", organization: org)
    UserPipelineAssignment.create!(user: owner, pipeline: pipeline, organization: org)
    DealStage.create!(name: "Closed", position: 1, pipeline: pipeline, organization: org)
  end

  describe "as an admin" do
    let(:admin) { create(:user) }
    let(:rep)   { create(:user, name: "Dana Rep") }

    before do
      ActsAsTenant.with_tenant(org) do
        create(:membership, :admin, user: admin, organization: org)
        admin.assign_role(:admin)
        create(:membership, :member, user: rep, organization: org)
        rep.assign_role(:associate)
      end
      as_user(admin)
    end

    it "renders KPI tiles, funnel and the per-rep table with real aggregates" do
      ActsAsTenant.with_tenant(org) do
        stage = build_stage(rep)
        c1 = create(:customer, organization: org, user: rep, status: "Converted")
        c2 = create(:customer, organization: org, user: rep, status: "Proposal Sent")
        make_call(user: rep, customer: c1, on: 2.days.ago, sid: "S1")
        make_call(user: rep, customer: c2, on: 3.days.ago, sid: "S2")
        make_deal(user: rep, customer: c1, status: "won", amount: 50_000,
                  closing_date: 1.day.ago.to_date, stage: stage)
      end

      get reports_path(filter_range: "30d")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Insights")
      # KPI tiles
      expect(response.body).to include("Calls")
      expect(response.body).to include("Leads worked")
      expect(response.body).to include("Conversion")
      # Funnel stages
      expect(response.body).to include("Conversion funnel")
      expect(response.body).to include("Contacted")
      expect(response.body).to include("Won")
      # Per-rep table with the rep's name
      expect(response.body).to include("Per-rep performance")
      expect(response.body).to include("Dana Rep")
      expect(response.body).to include("Target attainment")
      # No missing icons
      expect(response.body).not_to include("ic--missing")
    end

    it "narrows the window by the date-range preset" do
      ActsAsTenant.with_tenant(org) do
        c = create(:customer, organization: org, user: rep, status: "Pending")
        # One call 3 days ago (inside 7d), one 60 days ago (outside 7d, inside 90d).
        make_call(user: rep, customer: c, on: 3.days.ago, sid: "RECENT")
        make_call(user: rep, customer: c, on: 60.days.ago, sid: "OLD")
      end

      get reports_path(filter_range: "7d")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("7 days")
      # Only the recent call counts in the 7-day trend total.
      expect(response.body).to include("1 total")

      get reports_path(filter_range: "90d")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("90 days")
      # Both calls fall inside the 90-day window.
      expect(response.body).to include("2 total")
    end

    it "shows honest empty states with no data" do
      get reports_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No leads created in this range.")
      expect(response.body).not_to include("ic--missing")
    end
  end

  describe "as an associate (my_reports)" do
    let(:associate) { create(:user, name: "Sam Solo") }
    let(:other)     { create(:user, name: "Other Rep") }

    before do
      ActsAsTenant.with_tenant(org) do
        create(:membership, :member, user: associate, organization: org)
        associate.assign_role(:associate)
        create(:membership, :member, user: other, organization: org)
        other.assign_role(:associate)
      end
      as_user(associate)
    end

    it "renders the self-scoped dashboard without the per-rep table" do
      ActsAsTenant.with_tenant(org) do
        mine   = create(:customer, organization: org, user: associate, status: "Converted")
        theirs = create(:customer, organization: org, user: other, status: "Converted")
        make_call(user: associate, customer: mine, on: 2.days.ago, sid: "MINE")
        make_call(user: other, customer: theirs, on: 2.days.ago, sid: "THEIRS")
      end

      get my_reports_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Insights")
      expect(response.body).to include("Your performance")
      # No per-rep table for associates, and no other rep leaks in.
      expect(response.body).not_to include("Per-rep performance")
      expect(response.body).not_to include("Other Rep")
      expect(response.body).not_to include("ic--missing")
    end

    it "blocks associates from the team index" do
      get reports_path
      expect(response).to redirect_to(root_path)
    end
  end
end
