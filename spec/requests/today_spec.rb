require "rails_helper"

# Today dashboard coverage: role-aware KPI altitude (rep = own numbers,
# admin = team numbers), the manager layer, quick-complete and assign-to-me
# Turbo Stream flows. Mirrors the harness used by inbox_spec.
RSpec.describe "Relay Today dashboard", type: :request do
  let(:org)       { create(:organization, subdomain: "today-test") }
  let(:admin)     { create(:user) }
  let(:associate) { create(:user) }
  let(:host)      { "#{org.subdomain}.example.com" }

  before do
    # The role_setup initializer doesn't survive transactional tests — User#admin?
    # walks role_assignments, so the roles must exist here.
    { "admin" => 100, "manager" => 50, "associate" => 10 }.each do |key, level|
      Role.find_or_create_by!(key: key) { |r| r.name = key.capitalize; r.hierarchy_level = level }
    end
    ActsAsTenant.with_tenant(org) do
      create(:membership, :admin, user: admin, organization: org)
      create(:membership, user: associate, organization: org)
      admin.assign_role(:admin)
      associate.assign_role(:associate)
    end
    host! host
  end

  def sign_in(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  describe "admin view" do
    before { sign_in(admin) }

    it "shows the team layer and team-scoped KPIs" do
      ActsAsTenant.with_tenant(org) do
        # Activity belonging to ANOTHER user must surface in the admin's tiles.
        customer = create(:customer, organization: org, user: associate,
                          status: "Contact Established", updated_at: Time.current)
        pipeline = Pipeline.create!(name: "Spec pipeline", organization: org)
        stage = DealStage.create!(name: "Closed", pipeline: pipeline, position: 1, organization: org)
        associate.user_pipeline_assignments.create!(pipeline: pipeline, organization: org)
        Deal.create!(title: "Won deal", customer: customer, user: associate,
                     deal_stage: stage, amount: 5_000, status: "won",
                     closing_date: Date.current, organization: org)
      end

      get "/my_dashboard"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Team this month")
      expect(response.body).to include("· team")          # KPI tiles at team altitude
      expect(response.body).to include("$5.0k")            # associate's won deal in admin tile (compact format)
      expect(response.body).not_to include("ic--missing")
    end
  end

  describe "associate view" do
    before { sign_in(associate) }

    it "stays personal and hides the team layer" do
      get "/my_dashboard"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Team this month")
      expect(response.body).to include("· you")
    end
  end

  describe "quick-complete" do
    before { sign_in(admin) }

    it "completes the task and removes its row via Turbo Stream" do
      task = ActsAsTenant.with_tenant(org) do
        customer = create(:customer, organization: org, user: admin)
        Task.create!(title: "Call back", user: admin, customer: customer,
                     due_date: Date.current, status: "pending", priority: "High",
                     organization: org)
      end

      patch "/tasks/#{task.id}/complete",
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(action="remove")).and include("task_#{task.id}")
      expect(task.reload.status).to eq("completed")
    end
  end

  describe "assign to me" do
    before { sign_in(admin) }

    it "assigns in place: removes the unassigned row and toasts, no redirect" do
      lead = ActsAsTenant.with_tenant(org) do
        create(:customer, organization: org, user: nil, name: "Fresh Lead")
      end

      post "/customers/#{lead.id}/assign_to_self",
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("unassigned_customer_#{lead.id}")
      expect(response.body).to include("relay_toasts").and include("assigned to you")
      expect(lead.reload.user_id).to eq(admin.id)
    end

    it "keeps the redirect for plain HTML (Leads table path)" do
      lead = ActsAsTenant.with_tenant(org) do
        create(:customer, organization: org, user: nil)
      end

      post "/customers/#{lead.id}/assign_to_self"

      expect(response).to redirect_to("/customers")
    end
  end
end
