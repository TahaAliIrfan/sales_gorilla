class UserDashboardController < ApplicationController
  layout 'dashboard'
  before_action :require_login

  def index
    # Date ranges
    @today = Date.current
    @this_week_start = @today.beginning_of_week
    @this_month_start = @today.beginning_of_month
    
    # === CUSTOMER STATS ===
    @total_customers = current_user.customers.count
    @customers_this_month = current_user.customers.where(created_at: @this_month_start..Time.current).count
    
    # Customer status breakdown — single grouped query covering every status,
    # so the breakdown always sums to @total_customers
    @customer_status_counts = current_user.customers.group(:status).count

    # === DEAL STATS ===
    @total_deals = current_user.deals.count
    @active_deals = current_user.deals.active.count
    @won_deals = current_user.deals.won.count
    @lost_deals = current_user.deals.lost.count
    @total_deal_value = current_user.deals.sum(:amount)
    @won_deal_value = current_user.deals.won.sum(:amount)
    @lost_deal_value = current_user.deals.lost.sum(:amount)
    @active_deal_value = current_user.deals.active.sum(:amount)
    
    # Deals this month
    @deals_created_this_month = current_user.deals.where(created_at: @this_month_start..Time.current).count
    @deals_won_this_month = current_user.deals.won.where(closing_date: @this_month_start..@today).count
    @revenue_this_month = current_user.deals.won.where(closing_date: @this_month_start..@today).sum(:amount)
    
    # Win rate calculation
    closed_deals = @won_deals + @lost_deals
    @win_rate = closed_deals > 0 ? ((@won_deals.to_f / closed_deals) * 100).round(1) : 0
    
    # Deal stages for pipeline
    @deal_stages = DealStage.all
    @deals_by_stage = {}
    @deal_stages.each do |stage|
      @deals_by_stage[stage.id] = current_user.deals.active.by_stage(stage).count
    end
    
    # === CALL STATS ===
    my_recordings = Recording.where(user: current_user)
    my_recordings_today = my_recordings.where(date: @today.beginning_of_day..@today.end_of_day)
    my_recordings_this_week = my_recordings.where(date: @this_week_start..@today.end_of_day)
    my_recordings_this_month = my_recordings.where(date: @this_month_start..@today.end_of_day)
    
    # Today's calls
    @calls_today = my_recordings_today.count
    @connected_calls_today = my_recordings_today.where("duration >= ?", 120).count
    @attempted_calls_today = my_recordings_today.where("duration >= ? AND duration < ?", 40, 120).count
    @failed_calls_today = my_recordings_today.where("duration < ?", 40).count
    
    # This week's calls
    @calls_this_week = my_recordings_this_week.count
    @connected_calls_this_week = my_recordings_this_week.where("duration >= ?", 120).count
    
    # This month's calls
    @calls_this_month = my_recordings_this_month.count
    @connected_calls_this_month = my_recordings_this_month.where("duration >= ?", 120).count
    @attempted_calls_this_month = my_recordings_this_month.where("duration >= ? AND duration < ?", 40, 120).count
    @failed_calls_this_month = my_recordings_this_month.where("duration < ?", 40).count
    
    # Call success rate
    @call_success_rate = @calls_this_month > 0 ? ((@connected_calls_this_month.to_f / @calls_this_month) * 100).round(1) : 0
    
    # === TASK STATS ===
    open_tasks = current_user.tasks.where(status: %w[pending in_progress])
    @pending_tasks_count = current_user.tasks.pending.count
    @today_tasks_count = open_tasks.for_today.count
    @overdue_tasks_count = current_user.tasks.overdue.count
    @completed_tasks_this_month = current_user.tasks.where(status: 'completed', updated_at: @this_month_start..Time.current).count

    # Task lists. "Upcoming" excludes overdue tasks (they have their own panel).
    @today_tasks = open_tasks.for_today.order(due_date: :asc).limit(5)
    @overdue_tasks = current_user.tasks.overdue.order(due_date: :asc).limit(5)
    @upcoming_tasks_count = open_tasks.upcoming.count
    @upcoming_tasks = open_tasks.upcoming.order(due_date: :asc).limit(5)
    
    # === ITEMS NEEDING ATTENTION ===
    @deals_needing_attention = deals_needing_attention
    @customers_needing_attention = customers_needing_attention
    @needs_attention = @deals_needing_attention.any? || @customers_needing_attention.any?
    
    # === RECENT ACTIVITY ===
    @recent_customers = current_user.customers.order(updated_at: :desc).limit(5)
    # The panel is titled "My Active Deals" — only show active ones
    @recent_deals = current_user.deals.active.includes(:customer, :deal_stage).order(updated_at: :desc).limit(5)
  end

  private

  def require_login
    unless session[:user_id]
      flash[:error] = "You must be logged in to access this section"
      redirect_to root_path
    end
  end
  
  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
  
  def deals_needing_attention
    return [] unless current_user

    Deal.assigned_to(current_user)
        .active
        .where("expected_close_date <= ?", Date.today + 7.days)
        .where(
          "NOT EXISTS (SELECT 1 FROM deal_activities WHERE deal_activities.deal_id = deals.id AND deal_activities.created_at >= ?)",
          3.days.ago
        )
        .limit(10)
  end

  def customers_needing_attention
    return [] unless current_user

    Customer.where(user_id: current_user.id)
            .where(status: ['Pending', 'Contact Established'])
            .where(
              "NOT EXISTS (SELECT 1 FROM customer_activities WHERE customer_activities.customer_id = customers.id AND customer_activities.created_at >= ?)",
              5.days.ago
            )
            .limit(10)
  end
end
