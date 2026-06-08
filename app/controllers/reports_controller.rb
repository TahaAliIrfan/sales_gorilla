# Relay Insights (Phase 8) — KPI dashboard, trend chart, conversion funnel,
# per-rep performance vs derived targets and lead-source breakdown, ported from
# docs/design/relay-app/project/app/view-insights.jsx.
#
# Role scoping mirrors the legacy reports pages and the rest of Relay:
#   • admins  → every (non-admin) active user in the tenant
#   • managers → their assigned associates
#   • associates → themselves only, via #my_reports (no per-rep table)
#
# Date ranges: the new UI exposes 7d / 30d / 90d presets plus custom, but the
# legacy filter_range params (today/yesterday/last_week/month/custom) still
# resolve so old links keep working. Every KPI is computed for the selected
# window AND the immediately-preceding equal-length window so deltas are real.
#
# All aggregates are bounded by the window and grouped in the database (no Ruby
# fan-out, no customer_activities scans).
class ReportsController < TenantController
  layout "relay"
  before_action :require_login
  before_action :require_admin_or_manager, only: [ :index ]

  # Ordered funnel stages: label => the customer statuses that roll into it.
  # Top-of-funnel is "all leads in window"; each stage narrows toward Converted.
  FUNNEL_STAGES = [
    [ "Leads",      :all ],
    [ "Contacted",  [ "Contact Established", "Proposal Sent", "Converted", "Not Interested", "Retarget" ] ],
    [ "Proposal",   [ "Proposal Sent", "Converted" ] ],
    [ "Won",        [ "Converted" ] ]
  ].freeze

  WORKED_STATUSES = [ "Contact Established", "Converted", "Proposal Sent", "Not Interested", "Retarget" ].freeze

  def index
    setup_date_filters
    @scope_label = current_user.admin? ? "Team performance, conversion and targets." : "Your associates' performance, conversion and targets."

    @users = if current_user.admin?
               User.active_users.where.not(id: admin_user_ids)
    else
               current_user.associates.active_users
    end.to_a

    @show_per_rep = true
    load_dashboard
  end

  def my_reports
    setup_date_filters
    @scope_label = "Your performance, conversion and targets."

    @users = [ current_user ]
    @show_per_rep = false
    load_dashboard

    render "index"
  end

  private

  # IDs of users who administer the active org (owner/admin), via the per-org
  # membership role. Replaces the retired global Role/RoleAssignment join.
  def admin_user_ids
    User.joins(memberships: :access_role)
        .where(memberships: { organization_id: ActsAsTenant.current_tenant&.id })
        .where(roles: { key: %w[owner admin] })
        .select(:id)
  end

  def load_dashboard
    @user_ids = @users.map(&:id)
    compute_kpis
    compute_trend
    compute_funnel
    compute_per_rep if @show_per_rep
    compute_lead_sources
  end

  # === KPI tiles: current window + previous equal-length window for deltas ===
  def compute_kpis
    @kpis = {
      current: window_metrics(@start_date, @end_date),
      previous: window_metrics(@prev_start_date, @prev_end_date)
    }
  end

  # Four headline metrics over [from, to], all grouped/bounded in SQL.
  def window_metrics(from, to)
    calls = Recording.where(user_id: @user_ids, date: from..to).count

    leads_worked = Customer.where(user_id: @user_ids, status: WORKED_STATUSES,
                                  updated_at: from..to).count

    won = Deal.where(user_id: @user_ids, status: "won",
                     closing_date: from.to_date..to.to_date)
    won_value = won.sum(:amount).to_f
    won_count = won.count

    # Conversion = won / (won + lost) among deals closed in the window.
    lost_count = Deal.where(user_id: @user_ids, status: "lost",
                            closing_date: from.to_date..to.to_date).count
    closed = won_count + lost_count
    conversion = closed.positive? ? ((won_count.to_f / closed) * 100).round : 0

    { calls: calls, leads_worked: leads_worked, won_value: won_value,
      won_count: won_count, conversion: conversion }
  end

  # === Trend: calls per day across the window, one grouped query ===
  def compute_trend
    by_day = Recording.where(user_id: @user_ids, date: @start_date..@end_date)
                      .group("DATE(recordings.date)").count

    @trend_labels = []
    @trend_values = []
    # Cap the number of buckets so a wide custom range stays a readable chart:
    # group by day up to ~31 buckets, otherwise by week.
    days = (@end_date.to_date - @start_date.to_date).to_i + 1
    if days <= 31
      (@start_date.to_date..@end_date.to_date).each do |d|
        @trend_labels << d.strftime("%-m/%-d")
        @trend_values << (by_day[d] || 0)
      end
    else
      # Re-bucket the per-day counts into ISO weeks (still derived from one query).
      weekly = Hash.new(0)
      by_day.each { |d, n| weekly[d.beginning_of_week] += n }
      cursor = @start_date.to_date.beginning_of_week
      while cursor <= @end_date.to_date
        @trend_labels << cursor.strftime("%-m/%-d")
        @trend_values << weekly[cursor]
        cursor += 7
      end
    end
    @trend_total = @trend_values.sum
  end

  # === Funnel: customer status counts in the window, one grouped query ===
  def compute_funnel
    counts = Customer.where(user_id: @user_ids, created_at: @start_date..@end_date)
                     .group(:status).count
    total = counts.values.sum

    @funnel = FUNNEL_STAGES.map do |label, statuses|
      value = statuses == :all ? total : statuses.sum { |s| counts[s].to_i }
      pct = total.positive? ? ((value.to_f / total) * 100).round : 0
      { stage: label, value: value, pct: pct }
    end
  end

  # === Per-rep performance vs derived monthly target ===
  def compute_per_rep
    from = @start_date
    to = @end_date

    calls_by_user = Recording.where(user_id: @user_ids, date: from..to)
                             .group(:user_id).count
    leads_by_user = Customer.where(user_id: @user_ids, status: WORKED_STATUSES,
                                   updated_at: from..to).group(:user_id).count
    won = Deal.where(user_id: @user_ids, status: "won", closing_date: from.to_date..to.to_date)
    won_count_by_user = won.group(:user_id).count
    won_value_by_user = won.group(:user_id).sum(:amount)
    lost_by_user = Deal.where(user_id: @user_ids, status: "lost",
                              closing_date: from.to_date..to.to_date).group(:user_id).count

    target = helpers.relay_monthly_target
    @per_rep = @users.map do |user|
      won_value = won_value_by_user[user.id].to_f
      won_c = won_count_by_user[user.id].to_i
      lost_c = lost_by_user[user.id].to_i
      closed = won_c + lost_c
      {
        user: user,
        calls: calls_by_user[user.id].to_i,
        leads: leads_by_user[user.id].to_i,
        won_count: won_c,
        won_value: won_value,
        conversion: closed.positive? ? ((won_c.to_f / closed) * 100).round : 0,
        attainment: helpers.relay_attainment_pct(won_value, target)
      }
    end.sort_by { |r| -r[:won_value] }
  end

  # === Lead source performance: won deals by the lead's attribution source ===
  # One grouped query joining deals -> customers. Replaces the prototype's
  # hard-coded RX.SOURCE with real attribution.
  def compute_lead_sources
    rows = Deal.joins(:customer)
               .where(user_id: @user_ids, status: "won",
                      closing_date: @start_date.to_date..@end_date.to_date)
               .group("customers.lead_source")
               .select("customers.lead_source AS src, COUNT(deals.id) AS won_count, COALESCE(SUM(deals.amount), 0) AS won_value")
               .to_a

    total_value = rows.sum { |r| r.won_value.to_f }
    @lead_sources = rows.map { |r|
      {
        source: r.src.presence || "Unattributed",
        won_count: r.won_count.to_i,
        won_value: r.won_value.to_f,
        pct: total_value.positive? ? ((r.won_value.to_f / total_value) * 100).round : 0
      }
    }.sort_by { |r| -r[:won_value] }.first(4)
  end

  def require_login
    unless current_user
      flash[:error] = "You must be logged in to access this section"
      redirect_to root_path
    end
  end

  def require_admin_or_manager
    unless current_user&.admin? || current_user&.manager?
      flash[:error] = "You must be an admin or manager to access reports"
      redirect_to root_path
    end
  end

  # Resolve @start_date/@end_date (the selected window) and @prev_* (the
  # immediately-preceding equal-length window used for deltas). Supports the new
  # 7d/30d/90d presets plus the legacy filter_range values so old links work.
  def setup_date_filters
    @filter_range = params[:filter_range].presence || "30d"
    @custom_start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
    @custom_end_date   = params[:end_date].present? ? Date.parse(params[:end_date]) : nil

    case @filter_range
    when "today"
      @start_date = Time.current.beginning_of_day
      @end_date = Time.current.end_of_day
    when "yesterday"
      @start_date = 1.day.ago.beginning_of_day
      @end_date = 1.day.ago.end_of_day
    when "last_week"
      @start_date = 1.week.ago.beginning_of_week(:monday)
      @end_date = 1.week.ago.end_of_week(:monday).end_of_day
    when "month"
      @start_date = Time.current.beginning_of_month
      @end_date = Time.current.end_of_day
    when "7d"
      @start_date = 6.days.ago.beginning_of_day
      @end_date = Time.current.end_of_day
    when "90d"
      @start_date = 89.days.ago.beginning_of_day
      @end_date = Time.current.end_of_day
    when "custom"
      @start_date = @custom_start_date&.beginning_of_day || 29.days.ago.beginning_of_day
      @end_date = @custom_end_date&.end_of_day || Time.current.end_of_day
    else # "30d" and any unknown value
      @filter_range = "30d" unless %w[7d 30d 90d].include?(@filter_range)
      @start_date = 29.days.ago.beginning_of_day
      @end_date = Time.current.end_of_day
    end

    span = @end_date - @start_date
    @prev_end_date = @start_date - 1.second
    @prev_start_date = @prev_end_date - span
  end
end
