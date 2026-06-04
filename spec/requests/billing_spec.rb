require "rails_helper"

# Phase 9 Billing smoke + scoping coverage. Drives the real BillingController +
# views (invoices / estimates / proposals tabs) through a tenant subdomain
# request, verifying the tab counts, the invoices table, the estimates table,
# the proposals grid, and Pundit invoice scoping. Mirrors outreach_spec.rb.
RSpec.describe "Relay Billing", type: :request do
  let(:org)  { create(:organization, subdomain: "billing-test") }
  let(:host) { "#{org.subdomain}.example.com" }

  def as_user(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  # Build a milestone-backed invoice in the current tenant.
  def create_invoice(customer:, user:, status: "pending", due_date: 30.days.from_now)
    milestone = Milestone.create!(
      customer: customer, user: user, organization: org,
      name: "Pilot milestone", total_amount: 5_000, schedule_type: "milestone", status: "unpaid"
    )
    milestone.milestone_items.create!(description: "Outbound pilot — month 1", amount: 5_000, position: 0, organization: org)
    invoice = Invoice.new(
      customer: customer, user: user, milestone: milestone, organization: org,
      issue_date: Date.current, due_date: due_date, status: status
    )
    invoice.populate_from_milestone!(milestone)
    invoice.save!
    invoice
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

    it "renders the invoices tab with the cross-customer table" do
      ActsAsTenant.with_tenant(org) do
        cust = create(:customer, organization: org, user: admin, name: "Northwind Labs")
        create_invoice(customer: cust, user: admin)
      end

      get billing_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Quotes &amp; invoices")
      expect(response.body).to include("Northwind Labs")
      expect(response.body).to include("INV-")
      expect(response.body).to include("Mark paid")
      expect(response.body).not_to include("ic--missing")
    end

    it "renders the estimates tab" do
      ActsAsTenant.with_tenant(org) do
        admin.cost_estimates.create!(
          app_type: "web", description: "A solid web application build", scale: "mvp",
          customer_name: "Cobalt Health", hourly_rate: 100, total_hours: 50, total_cost: 5_000, status: "init"
        )
      end

      get billing_path(tab: "estimates")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Cobalt Health")
      expect(response.body).not_to include("ic--missing")
    end

    it "renders the proposals tab" do
      ActsAsTenant.with_tenant(org) do
        admin.odoo_proposals.create!(
          customer_name: "Lumen Robotics", deployment_type: "online", num_users: 10,
          selected_modules: %w[crm], organization: org
        )
      end

      get billing_path(tab: "proposals")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Lumen Robotics")
      expect(response.body).not_to include("ic--missing")
    end

    it "shows the empty invoices state" do
      get billing_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No invoices yet")
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

    it "scopes invoices to the associate's own customers" do
      ActsAsTenant.with_tenant(org) do
        mine   = create(:customer, organization: org, user: associate, name: "Mine Co")
        theirs = create(:customer, organization: org, user: other, name: "Theirs Co")
        create_invoice(customer: mine, user: associate)
        create_invoice(customer: theirs, user: other)
      end

      get billing_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Mine Co")
      expect(response.body).not_to include("Theirs Co")
    end
  end
end
