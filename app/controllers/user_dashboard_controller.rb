class UserDashboardController < ApplicationController
  layout 'dashboard'
  before_action :require_login

  def index
    # Get the current user's customers
    @my_customers = current_user.customers.order(created_at: :desc).limit(5)
    @total_customers = current_user.customers.count
    
    # Get the current user's deals
    @my_deals = current_user.deals.active.order(expected_close_date: :asc).limit(5)
    @total_deals = current_user.deals.count
    @active_deals = current_user.deals.active.count
    @won_deals = current_user.deals.won.count
    @lost_deals = current_user.deals.lost.count
    
    # Get value metrics
    @total_deal_value = current_user.deals.sum(:amount)
    @won_deal_value = current_user.deals.won.sum(:amount)
    
    # Get deals by stage for a simple pipeline overview
    @deal_stages = DealStage.all
    @deals_by_stage = {}
    @deal_stages.each do |stage|
      @deals_by_stage[stage.id] = current_user.deals.active.by_stage(stage).count
    end
    
    # Check for deals and customers that need attention
    @deals_needing_attention = deals_needing_attention
    @customers_needing_attention = customers_needing_attention
    @needs_attention = @deals_needing_attention.any? || @customers_needing_attention.any?
    
    # Get tasks for the user
    @pending_tasks = current_user.tasks.pending.order(due_date: :asc).limit(5)
    @today_tasks = current_user.tasks.for_today.order(due_date: :asc)
    @overdue_tasks = current_user.tasks.overdue.order(due_date: :asc)
    
    # Summary counts
    @pending_tasks_count = current_user.pending_tasks.count
    @today_tasks_count = current_user.tasks_for_today.count
    @overdue_tasks_count = current_user.overdue_tasks.count
    
    # Call success rate calculations
    calculate_call_success_rates
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
  
  def calculate_call_success_rates
    # Get recordings for the current user
    my_recordings = Recording.where(user: current_user)
    @my_successful_calls = my_recordings.where("duration >= ?", 60).count
    @my_failed_calls = my_recordings.where("duration < ?", 60).count
    
    # Calculate success rate for the current user
    total_my_calls = @my_successful_calls + @my_failed_calls
    @my_success_rate = total_my_calls.zero? ? 0 : ((@my_successful_calls.to_f / total_my_calls) * 100).round
    
    # Calculate team success rate
    all_recordings = Recording.all
    team_successful_calls = all_recordings.where("duration >= ?", 60).count
    total_team_calls = all_recordings.count
    @team_success_rate = total_team_calls.zero? ? 0 : ((team_successful_calls.to_f / total_team_calls) * 100).round
  end
  
  def deals_needing_attention
    return [] unless current_user
    
    # Deals that need attention criteria:
    # 1. Active deals assigned to current user
    # 2. Expected close date is within 7 days or has passed
    # 3. No activity in the last 3 days
    
    today = Date.today
    
    Deal.assigned_to(current_user)
        .active
        .where("expected_close_date <= ?", today + 7.days)
        .select do |deal|
          # Check if there's no recent activity
          last_activity = deal.deal_activities.order(created_at: :desc).first
          last_activity.nil? || last_activity.created_at < 3.days.ago
        end
  end
  
  def customers_needing_attention
    return [] unless current_user
    
    # Customers that need attention criteria:
    # 1. Assigned to current user
    # 2. Status is 'Pending' or 'Connection Established'
    # 3. No activity in the last 5 days
    
    Customer.where(user_id: current_user.id)
            .where(status: ['Pending', 'Connection Established'])
            .select do |customer|
              # Check if there's no recent activity
              last_activity = customer.customer_activities.order(created_at: :desc).first
              last_activity.nil? || last_activity.created_at < 5.days.ago
            end
  end
end 