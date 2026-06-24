class UserDashboardController < ApplicationController
  layout "relay"
  before_action :require_login

  ACTIVE_CUSTOMER_STATUSES = [ "Pending", "Lead", "Contact Established", "Proposal Sent", "Retarget" ].freeze
  WORKED_STATUSES = [ "Contact Established", "Converted", "Proposal Sent", "Not Interested" ].freeze

  def index
    @today = Date.current
    @month_start = @today.beginning_of_month
    @is_manager = current_user.admin? || current_user.manager?

    load_kpis
    load_followups
    load_queue
    load_unassigned
    load_pipeline
    load_team if @is_manager
  end

  private

  # KPI altitude: reps see their own numbers; managers/admins see their team's
  # (admins: whole org, managers: themselves + associates). Used by the KPI
  # tiles AND the pipeline snapshot so the subhead never mixes scopes.
  def kpi_user_ids
    @kpi_user_ids ||=
      if current_user.admin?
        User.ids
      elsif current_user.manager?
        [ current_user.id, *current_user.associates.ids ]
      else
        [ current_user.id ]
      end
  end

  # === KPI stat tiles ===
  def load_kpis
    recordings_today = Recording.where(user_id: kpi_user_ids)
                                .where(date: @today.beginning_of_day..@today.end_of_day)
    @calls_today = recordings_today.count
    @connected_today = recordings_today.where("duration >= ?", 120).count

    # Leads worked this month: customers moved past the initial pending state.
    @leads_worked = Customer.where(user_id: kpi_user_ids)
                            .where(status: WORKED_STATUSES)
                            .where(updated_at: @month_start..Time.current)
                            .count

    won_this_month = Deal.where(user_id: kpi_user_ids).won
                         .where(closing_date: @month_start..@today)
    @deals_won_value = won_this_month.sum(:amount)
    @deals_won_count = won_this_month.count

    won = Deal.where(user_id: kpi_user_ids).won.count
    lost = Deal.where(user_id: kpi_user_ids).lost.count
    closed = won + lost
    @conversion = closed.positive? ? ((won.to_f / closed) * 100).round : 0
  end

  # === Today's follow-ups (Tasks bucketed) ===
  def load_followups
    base = current_user.tasks.includes(:customer)
    @overdue_tasks  = base.overdue.order(due_date: :asc).to_a
    @today_tasks    = base.for_today.pending.order(due_date: :asc).to_a
    @upcoming_tasks = base.pending.where("due_date > ?", @today.end_of_day)
                          .order(due_date: :asc).limit(10).to_a
    @open_followups = @overdue_tasks.size + @today_tasks.size + @upcoming_tasks.size
    # The manager/admin subhead speaks about the team, so count the team's
    # open follow-ups (admins: whole org via tenant scoping; managers: their
    # associates + themselves), not just the viewer's own tasks.
    @team_open_followups =
      if current_user.admin?
        Task.pending.count
      elsif current_user.manager?
        Task.pending.where(user_id: [current_user.id, *current_user.associates.ids]).count
      end
    @done_today = current_user.tasks.completed
                              .where(updated_at: @today.beginning_of_day..@today.end_of_day)
                              .count
  end

  # === Your queue: this rep's active leads ===
  def load_queue
    @queue = current_user.customers
                         .where(status: ACTIVE_CUSTOMER_STATUSES)
                         .order(updated_at: :desc)
                         .limit(5)
                         .to_a
    @queue_count = current_user.customers.where(status: ACTIVE_CUSTOMER_STATUSES).count
  end

  # === Unassigned leads (assign to me) ===
  def load_unassigned
    @unassigned = Customer.where(user_id: nil)
                          .order(created_at: :desc)
                          .limit(6)
                          .to_a
    @unassigned_count = Customer.where(user_id: nil).count
  end

  # === Pipeline snapshot (same altitude as the KPI tiles) ===
  def load_pipeline
    open = Deal.where(user_id: kpi_user_ids).active
    @open_pipeline_value = open.sum(:amount)
    @open_pipeline_count = open.count

    won = Deal.where(user_id: kpi_user_ids).won.count
    lost = Deal.where(user_id: kpi_user_ids).lost.count
    closed = won + lost
    @win_rate = closed.positive? ? ((won.to_f / closed) * 100).round : 0
  end

  # === Manager / admin: team attainment ===
  def load_team
    associates = current_user.admin? ? current_organization.users.order(:name).to_a : current_user.associates.to_a
    associates = associates.reject { |u| u.id == current_user.id }

    start = @month_start
    @team = associates.map do |rep|
      calls = Recording.where(user_id: rep.id, date: start..Time.current).count
      leads = rep.customers.where(updated_at: start..Time.current).count
      won_value = rep.deals.won.where(closing_date: start..@today).sum(:amount)
      target = helpers.relay_monthly_target(@target_memo ||= {})
      attainment = helpers.relay_attainment_pct(won_value, target)
      { user: rep, calls: calls, leads: leads, won_value: won_value, attainment: attainment }
    end.sort_by { |r| -r[:attainment] }
  end

  # Auth comes from ApplicationController (require_login / current_user) — the
  # session-reading duplicates that used to live here diverged from the rest
  # of the app and were removed with the Relay redesign.
end
