class DashboardController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :require_admin, except: [:my_reports]

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
    
    # Get tasks data
    @pending_tasks_count = Task.pending.count
    @today_tasks_count = Task.for_today.count
    @overdue_tasks_count = Task.overdue.count
    
    # Get tasks by user for admin dashboard
    @users = User.all
    @tasks_by_user = {}
    @users.each do |user|
      @tasks_by_user[user.id] = {
        pending: user.tasks.pending.count,
        today: user.tasks.for_today.count,
        overdue: user.tasks.overdue.count
      }
    end
    
    # Get today's tasks across all users for admin view
    @today_tasks = Task.for_today.includes(:user, :customer).order(due_date: :asc).limit(10)
  end

  def reports
    # Date range setup
    @filter_range = params[:filter_range] || '30'
    @custom_start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
    @custom_end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil
    
    # Set date range based on filter
    case @filter_range
    when '30'
      @start_date = 30.days.ago.beginning_of_day
      @end_date = Time.current.end_of_day
    when '90'
      @start_date = 90.days.ago.beginning_of_day
      @end_date = Time.current.end_of_day
    when 'custom'
      @start_date = @custom_start_date.beginning_of_day if @custom_start_date
      @end_date = @custom_end_date.end_of_day if @custom_end_date
    else
      @start_date = 30.days.ago.beginning_of_day
      @end_date = Time.current.end_of_day
    end
    
    # User filter for admin
    @selected_user_id = params[:user_id]
    @users = User.all
    
    # Prepare data for all users or selected user
    if @selected_user_id.present?
      @selected_user = User.find(@selected_user_id)
      prepare_user_reports(@selected_user)
    else
      prepare_team_reports
    end
  end

  def my_reports
    # Date range setup
    @filter_range = params[:filter_range] || '30'
    @custom_start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
    @custom_end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil
    
    # Set date range based on filter
    case @filter_range
    when '30'
      @start_date = 30.days.ago.beginning_of_day
      @end_date = Time.current.end_of_day
    when '90'
      @start_date = 90.days.ago.beginning_of_day
      @end_date = Time.current.end_of_day
    when 'custom'
      @start_date = @custom_start_date.beginning_of_day if @custom_start_date
      @end_date = @custom_end_date.end_of_day if @custom_end_date
    else
      @start_date = 30.days.ago.beginning_of_day
      @end_date = Time.current.end_of_day
    end
    
    # Prepare data for current user
    prepare_user_reports(current_user)
    
    render 'user_reports'
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
  
  def prepare_team_reports
    # Team performance metrics
    @user_deal_counts = {}
    @user_deal_values = {}
    @user_won_deals = {}
    @user_active_deals = {}
    
    @users.each do |user|
      @user_deal_counts[user.id] = Deal.assigned_to(user).where(created_at: @start_date..@end_date).count
      @user_deal_values[user.id] = Deal.assigned_to(user).where(created_at: @start_date..@end_date).sum(:amount)
      @user_won_deals[user.id] = Deal.assigned_to(user).won.where(created_at: @start_date..@end_date).count
      @user_active_deals[user.id] = Deal.assigned_to(user).active.where(created_at: @start_date..@end_date).count
    end
    
    # Monthly performance data for charts
    begin
      # Try to use groupdate gem if available
      @monthly_deals = Deal.where(created_at: @start_date..@end_date).group_by_month(:created_at, last: 6).count
      @monthly_won_deals = Deal.won.where(created_at: @start_date..@end_date).group_by_month(:created_at, last: 6).count
      @monthly_deal_values = Deal.where(created_at: @start_date..@end_date).group_by_month(:created_at, last: 6).sum(:amount)
    rescue NoMethodError
      # Fallback to manual grouping if groupdate gem is not available
      @monthly_deals = group_by_month_manual(Deal.where(created_at: @start_date..@end_date), 6)
      @monthly_won_deals = group_by_month_manual(Deal.won.where(created_at: @start_date..@end_date), 6)
      @monthly_deal_values = group_by_month_manual_sum(Deal.where(created_at: @start_date..@end_date), :amount, 6)
    end
    
    # Additional team metrics
    prepare_sales_rep_metrics(nil)
    prepare_communication_metrics(nil)
  end
  
  def prepare_user_reports(user)
    # Monthly performance data for charts for one user
    begin
      # Try to use groupdate gem if available
      @monthly_deals = Deal.assigned_to(user).where(created_at: @start_date..@end_date).group_by_month(:created_at, last: 6).count
      @monthly_won_deals = Deal.assigned_to(user).won.where(created_at: @start_date..@end_date).group_by_month(:created_at, last: 6).count
      @monthly_deal_values = Deal.assigned_to(user).where(created_at: @start_date..@end_date).group_by_month(:created_at, last: 6).sum(:amount)
    rescue NoMethodError
      # Fallback to manual grouping if groupdate gem is not available
      @monthly_deals = group_by_month_manual(Deal.assigned_to(user).where(created_at: @start_date..@end_date), 6)
      @monthly_won_deals = group_by_month_manual(Deal.assigned_to(user).won.where(created_at: @start_date..@end_date), 6)
      @monthly_deal_values = group_by_month_manual_sum(Deal.assigned_to(user).where(created_at: @start_date..@end_date), :amount, 6)
    end
    
    # Prepare individual metrics
    prepare_sales_rep_metrics(user)
    prepare_communication_metrics(user)
  end
  
  def prepare_sales_rep_metrics(user)
    customer_scope = user ? Customer.where(user_id: user.id) : Customer
    deal_scope = user ? Deal.assigned_to(user) : Deal
    
    # Filter by date range
    date_filtered_customers = customer_scope.where(created_at: @start_date..@end_date)
    date_filtered_deals = deal_scope.where(created_at: @start_date..@end_date)
    
    # Total assigned leads (customers)
    @total_assigned_leads = date_filtered_customers.count
    
    # Lead sources distribution for pie chart
    @lead_source_distribution = date_filtered_customers.group(:lead_source).count
    
    # Deal metrics
    @total_deals = date_filtered_deals.count
    @deal_stage_distribution = date_filtered_deals.joins(:deal_stage).group('deal_stages.name').count
    @total_deal_value = date_filtered_deals.sum(:amount)
    
    # Customer status metrics
    @connection_established_percentage = view_context.calculate_percentage(date_filtered_customers.where(status: 'Contact Established').count, @total_assigned_leads)
    @not_interested_percentage = view_context.calculate_percentage(date_filtered_customers.where(status: 'Not Interested').count, @total_assigned_leads)
    @discovery_call_booked_percentage = view_context.calculate_percentage(date_filtered_customers.where(status: 'Proposal Sent').count, @total_assigned_leads)
    @unresponsive_percentage = view_context.calculate_percentage(date_filtered_customers.where(status: 'Unresponsive').count, @total_assigned_leads)
    @conversion_count = date_filtered_customers.where(status: 'Converted').count
    @conversion_percentage = view_context.calculate_percentage(@conversion_count, @total_assigned_leads)
  end
  
  def prepare_communication_metrics(user)
    customer_scope = user ? Customer.where(user_id: user.id) : Customer
    date_filtered_customers = customer_scope.where(created_at: @start_date..@end_date)
    
    # Call metrics
    @total_calls_daily = {}
    (@start_date.to_date..@end_date.to_date).each do |date|
      @total_calls_daily[date] = date_filtered_customers.where(call_status: 'Called', updated_at: date.beginning_of_day..date.end_of_day).count
    end
    
    @total_calls_weekly = {}
    start_week = @start_date.to_date.beginning_of_week
    end_week = @end_date.to_date.end_of_week
    current_week = start_week
    
    while current_week <= end_week
      week_end = [current_week.end_of_week, @end_date.to_date].min
      @total_calls_weekly[current_week] = date_filtered_customers.where(call_status: 'Called', updated_at: current_week.beginning_of_day..week_end.end_of_day).count
      current_week = current_week.next_week
    end
    
    @calls_connected_count_monthly = date_filtered_customers.where(call_status: 'Connected').count
    @total_calls_monthly = date_filtered_customers.where(call_status: ['Called', 'Connected']).count
    @calls_connected_percentage_monthly = view_context.calculate_percentage(@calls_connected_count_monthly, @total_calls_monthly)
    
    # WhatsApp metrics
    @whatsapp_conversations_monthly = date_filtered_customers.where(whatsapp_status: ['Message Sent', 'Connected']).count
    
    # Email metrics
    @email_conversations_monthly = date_filtered_customers.where(email_status: ['Email Sent', 'Connected']).count
    
    # LinkedIn metrics
    @linkedin_conversations_monthly = date_filtered_customers.where(linkedin_status: ['Message Sent', 'Conversation Initiated']).count
  end
end
