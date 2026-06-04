require "rails_helper"

# Phase 9 public invoice page. Drives PublicInvoicesController#show on the ROOT
# domain with NO authentication, verifying the restyled, tenant-branded
# standalone page renders: org name, invoice number, line items, totals, the
# payment-proof upload form, and the brand color ramp derived from the invoice's
# organization (relay_brand_style_tag → --brand-* oklch vars).
RSpec.describe "Public invoice page", type: :request do
  let(:org) do
    create(:organization, subdomain: "branded-co", name: "Branded Co", primary_color: "#7C3AED")
  end

  def build_viewable_invoice
    ActsAsTenant.with_tenant(org) do
      user = create(:user)
      create(:membership, :admin, user: user, organization: org)
      customer = create(:customer, organization: org, user: user, name: "Acme Widgets")
      milestone = Milestone.create!(
        customer: customer, user: user, organization: org,
        name: "Launch milestone", total_amount: 8_500, schedule_type: "milestone", status: "unpaid"
      )
      milestone.milestone_items.create!(description: "Outbound pilot — month 1", amount: 8_500, position: 0, organization: org)
      invoice = Invoice.new(
        customer: customer, user: user, milestone: milestone, organization: org,
        issue_date: Date.current, due_date: 14.days.from_now, status: "pending"
      )
      invoice.populate_from_milestone!(milestone)
      invoice.save!
      invoice
    end
  end

  before do
    Role.seed_default_roles
    host! "example.com" # ROOT domain — no tenant subdomain
  end

  it "renders unauthenticated with tenant branding" do
    invoice = build_viewable_invoice
    expect(invoice.publicly_viewable?).to be true

    get public_invoice_path(invoice.public_token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Branded Co")          # org name (branding)
    expect(response.body).to include(invoice.invoice_number) # mono invoice no.
    expect(response.body).to include("Acme Widgets")         # bill-to customer
    expect(response.body).to include("Outbound pilot — month 1") # line item
    expect(response.body).to include("Total due")            # totals block
    expect(response.body).to include("Payment proof")        # upload area
    expect(response.body).to include("invoice[payment_proof]") # unchanged param name
    expect(response.body).to include("--brand-500")          # brand ramp from org color
    expect(response.body).not_to include("ic--missing")
  end

  it "returns not_found for an unknown token" do
    get public_invoice_path("nope-nope-nope")
    expect(response).to have_http_status(:not_found)
  end
end
