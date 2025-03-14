class DashboardController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :require_admin

  def index
    @total_customers = Customer.count
    @total_deals = Deal.count
    @active_deals = Deal.active.count
    @won_deals = Deal.won.count
    @lost_deals = Deal.lost.count
    @total_deal_value = Deal.sum(:amount)
    @won_deal_value = Deal.won.sum(:amount)
    
    # Get deals for the current user
    @my_deals = current_user ? Deal.assigned_to(current_user).active.order(expected_close_date: :asc).limit(5) : []
    
    # Get recent deals
    @recent_deals = Deal.order(created_at: :desc).limit(5)
    
    # Get deals by stage for a simple pipeline overview
    @deal_stages = DealStage.all
    @deals_by_stage = {}
    @deal_stages.each do |stage|
      @deals_by_stage[stage.id] = Deal.active.by_stage(stage).count
    end
    
    # Check for deals and customers that need attention
    @deals_needing_attention = deals_needing_attention
    @customers_needing_attention = customers_needing_attention
    @needs_attention = @deals_needing_attention.any? || @customers_needing_attention.any?
  end

  def reports
    # Team performance metrics
    @users = User.all
    @user_deal_counts = {}
    @user_deal_values = {}
    @user_won_deals = {}
    @user_active_deals = {}
    
    @users.each do |user|
      @user_deal_counts[user.id] = Deal.assigned_to(user).count
      @user_deal_values[user.id] = Deal.assigned_to(user).sum(:amount)
      @user_won_deals[user.id] = Deal.assigned_to(user).won.count
      @user_active_deals[user.id] = Deal.assigned_to(user).active.count
    end
    
    # Monthly performance data for charts
    begin
      # Try to use groupdate gem if available
      @monthly_deals = Deal.group_by_month(:created_at, last: 6).count
      @monthly_won_deals = Deal.won.group_by_month(:created_at, last: 6).count
      @monthly_deal_values = Deal.group_by_month(:created_at, last: 6).sum(:amount)
    rescue NoMethodError
      # Fallback to manual grouping if groupdate gem is not available
      @monthly_deals = group_by_month_manual(Deal.all, 6)
      @monthly_won_deals = group_by_month_manual(Deal.won, 6)
      @monthly_deal_values = group_by_month_manual_sum(Deal.all, :amount, 6)
    end
  end

  private

  def require_login
    unless session[:user_id]
      flash[:error] = "You must be logged in to access this section"
      redirect_to root_path
    end
  end
  
  def require_admin
    unless current_user&.admin?
      flash[:error] = "You must be an admin to access the dashboard"
      redirect_to root_path
    end
  end
  
  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
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
  
  # Manual implementation of group_by_month for fallback
  def group_by_month_manual(scope, months_count)
    result = {}
    
    # Get the last N months
    end_date = Date.today.end_of_month
    start_date = (end_date - (months_count - 1).months).beginning_of_month
    
    # Create a hash with all months initialized to 0
    current_date = start_date
    while current_date <= end_date
      result[current_date] = 0
      current_date = current_date.next_month
    end
    
    # Count records for each month
    scope.where(created_at: start_date.beginning_of_day..end_date.end_of_day).each do |record|
      month_start = Date.new(record.created_at.year, record.created_at.month, 1)
      result[month_start] += 1 if result.key?(month_start)
    end
    
    result
  end
  
  # Manual implementation of group_by_month with sum for fallback
  def group_by_month_manual_sum(scope, field, months_count)
    result = {}
    
    # Get the last N months
    end_date = Date.today.end_of_month
    start_date = (end_date - (months_count - 1).months).beginning_of_month
    
    # Create a hash with all months initialized to 0
    current_date = start_date
    while current_date <= end_date
      result[current_date] = 0
      current_date = current_date.next_month
    end
    
    # Sum values for each month
    scope.where(created_at: start_date.beginning_of_day..end_date.end_of_day).each do |record|
      month_start = Date.new(record.created_at.year, record.created_at.month, 1)
      result[month_start] += record.send(field) if result.key?(month_start)
    end
    
    result
  end
end
