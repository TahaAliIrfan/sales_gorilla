# Relay Billing (Phase 9) — the "Quotes & invoices" workspace, one console over
# three concerns that used to live in separate controllers, ported from
# docs/design/relay-app/project/app/billing.jsx:
#
#   • Invoices  — every invoice across the book (mirrors AllInvoicesController#index)
#   • Estimates — AI cost estimates (mirrors CostEstimatesController#index)
#   • Proposals — Odoo proposals (mirrors OdooProposalsController#index)
#
# Tabs are server-side via ?tab=invoices|estimates|proposals so each is linkable.
# The legacy CRUD pages (all_invoices / invoices / cost_estimates /
# odoo_proposals) stay untouched and reachable behind View / New / actions.
#
# Scoping mirrors each source controller's index:
#   • Invoices  — Pundit policy_scope(Invoice) (joins customers, merges the
#                 Customer scope: admins all, managers their tree, associates own).
#   • Estimates — current_user.cost_estimates (each user owns their estimates).
#   • Proposals — current_user.odoo_proposals (each user owns their proposals).
class BillingController < TenantController
  layout "relay"
  before_action :require_login

  TABS = %w[invoices estimates proposals].freeze

  # GET /billing?tab=invoices|estimates|proposals
  def index
    @tab = TABS.include?(params[:tab]) ? params[:tab] : "invoices"

    load_invoices  # always loaded — drives the Invoices tab + tab count
    @estimates_count = current_user.cost_estimates.count
    @proposals_count = current_user.odoo_proposals.count

    case @tab
    when "estimates" then load_estimates
    when "proposals" then load_proposals
    end
  end

  private

  # Invoices across the book — same scope + includes as AllInvoicesController.
  def load_invoices
    @invoices = policy_scope(Invoice)
      .includes(:customer, :milestone, :user)
      .order(created_at: :desc)
      .page(params[:page]).per(20)
    # Tab count = total invoices in scope (independent of the paginated window).
    @invoices_count = policy_scope(Invoice).count
  end

  # Cost estimates — same scope as CostEstimatesController#index.
  def load_estimates
    @cost_estimates = current_user.cost_estimates
      .includes(:customer)
      .order(created_at: :desc)
      .page(params[:page])
  end

  # Odoo proposals — same scope as OdooProposalsController#index.
  def load_proposals
    @proposals = current_user.odoo_proposals
      .includes(:customer)
      .order(created_at: :desc)
  end
end
