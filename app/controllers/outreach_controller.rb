# Relay Outreach (Phase 7) — one workspace over three concerns that used to
# live in separate controllers, ported from
# docs/design/relay-app/project/app/view-outreach.jsx:
#
#   • Campaigns  — bulk WhatsApp sends with per-recipient execution status
#   • Audiences  — customer groups with member counts
#   • Templates  — approved Twilio WhatsApp templates (admin-only, mirrors
#                  WhatsappTemplatesController#index)
#
# Tabs are server-side via ?tab=campaigns|audiences|templates so each is
# linkable. The legacy CampaignsController / CustomerGroupsController /
# WhatsappTemplatesController CRUD pages stay untouched and reachable.
#
# Scoping mirrors each source controller's index: Pundit policy_scope for
# campaigns and groups (admins see all, managers see their tree, associates
# see their own), and the admin gate for templates. Per-recipient execution
# counts for every visible campaign are loaded in ONE grouped query and
# reshaped in Ruby, so the campaigns tab never N+1s.
class OutreachController < TenantController
  layout "relay"
  before_action :require_login
  after_action :verify_policy_scoped, only: :index

  TABS = %w[campaigns audiences templates].freeze

  # GET /outreach?tab=campaigns|audiences|templates
  def index
    @tab = TABS.include?(params[:tab]) ? params[:tab] : "campaigns"
    # Associates/managers can't reach the templates tab (admin-only resource).
    @tab = "campaigns" if @tab == "templates" && !current_user.admin?
    @show_templates_tab = current_user.admin?

    load_campaigns   # always loaded — drives the Campaigns tab + tab count
    load_groups      # drives the Audiences tab + tab count
    load_templates if @show_templates_tab

    # Always run a policy scope so verify_policy_scoped is satisfied even on the
    # (admin-only) templates tab, which is gated by role rather than Pundit.
    policy_scope(Campaign) if @tab == "templates"
  end

  private

  # Visible campaigns plus a {campaign_id => {pending:, completed:, failed:}}
  # map of per-recipient execution counts built from ONE grouped query.
  def load_campaigns
    @campaigns = policy_scope(Campaign).order(created_at: :desc).to_a
    @execution_counts = execution_counts_for(@campaigns.map(&:id))
  end

  # Customer groups with member counts in a single counter query (no N+1 on
  # customer_count). Mirrors CustomerGroupsController#index scoping.
  def load_groups
    @customer_groups = policy_scope(CustomerGroup)
                       .left_joins(:customer_group_memberships)
                       .select("customer_groups.*, COUNT(customer_group_memberships.id) AS members_count")
                       .group("customer_groups.id")
                       .order(created_at: :desc)
  end

  # Mirrors WhatsappTemplatesController#index (admin-gated by @show_templates_tab).
  def load_templates
    @templates      = WhatsappTemplate.ordered
    @last_synced_at = @templates.filter_map(&:last_synced_at).max
  end

  # One query: CampaignExecution grouped by (campaign_id, status), reshaped into
  # a per-campaign hash of {pending:, completed:, failed:, total:}. pending here
  # folds the model's "pending" + "processing" (both still-in-flight) statuses.
  def execution_counts_for(campaign_ids)
    blank = -> { { pending: 0, completed: 0, failed: 0, total: 0 } }
    counts = Hash.new { |h, k| h[k] = blank.call }
    return counts if campaign_ids.empty?

    CampaignExecution
      .where(campaign_id: campaign_ids)
      .group(:campaign_id, :status)
      .count
      .each do |(campaign_id, status), n|
        bucket = case status
                 when "completed" then :completed
                 when "failed"    then :failed
                 else                  :pending # pending + processing
        end
        counts[campaign_id][bucket] += n
        counts[campaign_id][:total] += n
      end

    counts
  end
end
