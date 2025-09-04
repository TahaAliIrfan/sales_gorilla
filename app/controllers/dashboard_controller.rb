class DashboardController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :require_admin, except: [:my_reports]

  def index
    # Setup filter parameters for AJAX requests
    @filter_range = params[:filter_range] || '30'
    @custom_start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
    @custom_end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil
    @selected_user_id = params[:user_id]
    @selected_user = @selected_user_id.present? ? User.find(@selected_user_id) : nil
    
    # Set period name for display
    @period_name = case @filter_range
                   when '7' then "Last 7 Days"
                   when '30' then "Last 30 Days"
                   when '90' then "Last 90 Days"
                   when 'custom' then "Custom Range"
                   else "Last 30 Days"
                   end
    
    # Only load essential data for initial page load
    @users = User.where.not(id: User.joins(:roles).where(roles: { name: 'admin' }).select(:id))  # Needed for filter dropdown
    
    # Quick stats (cached)
    Rails.cache.fetch("dashboard_quick_stats", expires_in: 5.minutes) do
      @total_customers = Customer.count
      @total_deals = Deal.count
      @active_deals = Deal.active.count
      @won_deals = Deal.won.count
      @total_deal_value = Deal.sum(:amount)
      {
        total_customers: @total_customers,
        total_deals: @total_deals,
        active_deals: @active_deals,
        won_deals: @won_deals,
        total_deal_value: @total_deal_value
      }
    end.tap do |cached_stats|
      @total_customers = cached_stats[:total_customers]
      @total_deals = cached_stats[:total_deals]
      @active_deals = cached_stats[:active_deals]
      @won_deals = cached_stats[:won_deals]
      @total_deal_value = cached_stats[:total_deal_value]
    end
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
    @users = User.where.not(id: User.joins(:roles).where(roles: { name: 'admin' }).select(:id))
    
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

  # AJAX endpoint for team overview data
  def team_overview
    start_date, end_date = get_date_range
    selected_user_id = params[:user_id]
    
    cache_key = "dashboard_team_overview_#{start_date.to_i}_#{end_date.to_i}_#{selected_user_id}"
    
    @team_overview = Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      analytics = AdminAnalyticsService.new(
        start_date: start_date,
        end_date: end_date,
        user_id: selected_user_id
      )
      analytics.team_performance_overview
    end
    
    render json: @team_overview
  end

  # AJAX endpoint for user performance data
  def user_performance
    start_date, end_date = get_date_range
    selected_user_id = params[:user_id]
    
    cache_key = "dashboard_user_performance_#{start_date.to_i}_#{end_date.to_i}_#{selected_user_id}"
    
    @user_performance = Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      analytics = AdminAnalyticsService.new(
        start_date: start_date,
        end_date: end_date,
        user_id: selected_user_id
      )
      analytics.user_performance_summary
    end
    
    render json: @user_performance
  end

  # AJAX endpoint for communication analytics
  def communication_analytics
    start_date, end_date = get_date_range
    selected_user_id = params[:user_id]
    
    cache_key = "dashboard_communication_analytics_#{start_date.to_i}_#{end_date.to_i}_#{selected_user_id}"
    
    @communication_analytics = Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      analytics = AdminAnalyticsService.new(
        start_date: start_date,
        end_date: end_date,
        user_id: selected_user_id
      )
      analytics.communication_analytics
    end
    
    render json: @communication_analytics
  end

  # AJAX endpoint for deal pipeline analytics
  def deal_analytics
    start_date, end_date = get_date_range
    selected_user_id = params[:user_id]
    
    cache_key = "dashboard_deal_analytics_#{start_date.to_i}_#{end_date.to_i}_#{selected_user_id}"
    
    @deal_analytics = Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      analytics = AdminAnalyticsService.new(
        start_date: start_date,
        end_date: end_date,
        user_id: selected_user_id
      )
      analytics.deal_pipeline_analytics
    end
    
    render json: @deal_analytics
  end

  # AJAX endpoint for recent deals and pipeline
  def team_performance
    @users = User.where.not(id: User.joins(:roles).where(roles: { name: 'admin' }).select(:id))
                .includes(:recordings, :deals, :tasks, :customers)
                .order(:name)
    
    analytics = AdminAnalyticsService.new(
      start_date: Date.current.beginning_of_day,
      end_date: Date.current.end_of_day
    )
    
    @daily_team_performance = analytics.daily_team_performance_overview(@users)
  end

  def quick_data
    @recent_deals = Rails.cache.fetch("dashboard_recent_deals", expires_in: 5.minutes) do
      Deal.includes(:customer, :deal_stage).order(created_at: :desc).limit(5)
    end
    
    @deal_stages = Rails.cache.fetch("dashboard_deal_stages", expires_in: 30.minutes) do
      DealStage.all
    end
    
    @deals_by_stage = Rails.cache.fetch("dashboard_deals_by_stage", expires_in: 5.minutes) do
      stages_hash = {}
      @deal_stages.each do |stage|
        stages_hash[stage.id] = Deal.active.by_stage(stage).count
      end
      stages_hash
    end
    
    @pending_tasks_count = Rails.cache.fetch("dashboard_pending_tasks", expires_in: 2.minutes) do
      Task.pending.count
    end
    
    @today_tasks_count = Rails.cache.fetch("dashboard_today_tasks", expires_in: 2.minutes) do
      Task.for_today.count
    end
    
    @overdue_tasks_count = Rails.cache.fetch("dashboard_overdue_tasks", expires_in: 2.minutes) do
      Task.overdue.count
    end
    
    @today_tasks = Rails.cache.fetch("dashboard_today_tasks_list", expires_in: 5.minutes) do
      Task.for_today.includes(:user, :customer).order(due_date: :asc).limit(10)
    end
    
    render json: {
      recent_deals: @recent_deals.as_json(include: [:customer, :deal_stage]),
      deal_stages: @deal_stages.as_json,
      deals_by_stage: @deals_by_stage,
      pending_tasks_count: @pending_tasks_count,
      today_tasks_count: @today_tasks_count,
      overdue_tasks_count: @overdue_tasks_count,
      today_tasks: @today_tasks.as_json(include: [:user, :customer])
    }
  end

  private

  def get_date_range
    filter_range = params[:filter_range] || '30'
    custom_start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
    custom_end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil
    
    case filter_range
    when '7'
      start_date = 7.days.ago.beginning_of_day
      end_date = Time.current.end_of_day
    when '30'
      start_date = 30.days.ago.beginning_of_day
      end_date = Time.current.end_of_day
    when '90'
      start_date = 90.days.ago.beginning_of_day
      end_date = Time.current.end_of_day
    when 'custom'
      start_date = custom_start_date&.beginning_of_day || 30.days.ago.beginning_of_day
      end_date = custom_end_date&.end_of_day || Time.current.end_of_day
    else
      start_date = 30.days.ago.beginning_of_day
      end_date = Time.current.end_of_day
    end
    
    [start_date, end_date]
  end

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
  
  # Manual implementation of group_by_month for recordings
  def group_by_month_manual_for_recordings(scope, months_count)
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
    scope.where(date: start_date.beginning_of_day..end_date.end_of_day).each do |record|
      month_start = Date.new(record.date.year, record.date.month, 1)
      result[month_start] += 1 if result.key?(month_start)
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
    prepare_user_progression_metrics
  end
  
  def prepare_user_reports(user)
    # Monthly performance data for charts for one user
    begin
      # Try to use groupdate gem if available
      @monthly_deals = Deal.assigned_to(user).where(created_at: @start_date..@end_date).group_by_month(:created_at, last: 6).count
      @monthly_won_deals = Deal.assigned_to(user).won.where(closing_date: @start_date.to_date..@end_date.to_date).group_by_month(:closing_date, last: 6).count
      @monthly_deal_values = Deal.assigned_to(user).where(created_at: @start_date..@end_date).group_by_month(:created_at, last: 6).sum(:amount)
    rescue NoMethodError
      # Fallback to manual grouping if groupdate gem is not available
      @monthly_deals = group_by_month_manual(Deal.assigned_to(user).where(created_at: @start_date..@end_date), 6)
      @monthly_won_deals = group_by_month_manual(Deal.assigned_to(user).won.where(closing_date: @start_date.to_date..@end_date.to_date), 6)
      @monthly_deal_values = group_by_month_manual_sum(Deal.assigned_to(user).where(created_at: @start_date..@end_date), :amount, 6)
    end
    
    # Prepare individual metrics
    prepare_sales_rep_metrics(user)
    prepare_communication_metrics(user)
    
    # Prepare individual progression metrics
    @user_progression_metrics = {}
    pending_count = Customer.where(user_id: user.id, status: 'Pending').where(created_at: @start_date..@end_date).count
    contact_established_count = Customer.where(user_id: user.id, status: 'Contact Established').where(created_at: @start_date..@end_date).count
    
    # Combined count for Contact Not Established and Unresponsive
    contact_not_established_count = Customer.where(user_id: user.id, status: ['Contact Not Established', 'Unresponsive']).where(created_at: @start_date..@end_date).count
    
    # Get counts for additional statuses
    exhausted_count = Customer.where(user_id: user.id, status: 'Exhausted').where(created_at: @start_date..@end_date).count
    invalid_count = Customer.where(user_id: user.id, status: 'Invalid').where(created_at: @start_date..@end_date).count
    
    deals_created_count = Deal.joins(:customer).where(customers: { user_id: user.id }).where(deals: { created_at: @start_date..@end_date }).count
    deals_won_count = Deal.joins(:customer).where(customers: { user_id: user.id }).where(deals: { status: 'won', closing_date: @start_date.to_date..@end_date.to_date }).count
    
    @user_progression_metrics[user.id] = {
      'Pending' => pending_count,
      'Contact Established' => contact_established_count,
      'Contact Not Established / Unresponsive' => contact_not_established_count,
      'Exhausted' => exhausted_count,
      'Invalid' => invalid_count,
      'Deals Created' => deals_created_count,
      'Deals Won' => deals_won_count
    }
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
    
    # Clean up the lead source data - replace blank/nil with "Unknown"
    cleaned_lead_source_distribution = {}
    @lead_source_distribution.each do |source, count|
      key = source.presence || "Unknown"
      cleaned_lead_source_distribution[key] = count
    end
    @lead_source_distribution = cleaned_lead_source_distribution
    
    # Deal metrics
    @total_deals = date_filtered_deals.count
    @deal_stage_distribution = date_filtered_deals.joins(:deal_stage).group('deal_stages.name').count
    @total_deal_value = date_filtered_deals.sum(:amount)
    
    # Additional deal metrics - won and lost deals (filter by closing_date instead of created_at)
    @total_won_deals = deal_scope.won.where(closing_date: @start_date.to_date..@end_date.to_date).count
    @total_won_deal_value = deal_scope.won.where(closing_date: @start_date.to_date..@end_date.to_date).sum(:amount)
    @total_lost_deals = deal_scope.lost.where(closing_date: @start_date.to_date..@end_date.to_date).count
    @total_lost_deal_value = deal_scope.lost.where(closing_date: @start_date.to_date..@end_date.to_date).sum(:amount)
    
    # System call metrics
    recording_scope = user ? Recording.where(user: user) : Recording
    @total_system_calls = recording_scope.where(date: @start_date..@end_date).count
    
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
    
    # Recording scope for system calls
    recording_scope = user ? Recording.where(user: user) : Recording
    date_filtered_recordings = recording_scope.where(date: @start_date..@end_date)
    
    # Calculate successful and failed communications based on call duration
    @successful_calls_count = date_filtered_recordings.where("duration >= ?", 120).count
    @failed_calls_count = date_filtered_recordings.where("duration < ?", 40).count
    @successful_calls_percentage = view_context.calculate_percentage(@successful_calls_count, (@successful_calls_count + @failed_calls_count))
    
    # Monthly system calls data for charts
    begin
      # Try to use groupdate gem if available
      @monthly_system_calls = recording_scope.where(date: @start_date..@end_date).group_by_month(:date, last: 6).count
      @monthly_successful_calls = recording_scope.where(date: @start_date..@end_date).where("duration >= ?", 120).group_by_month(:date, last: 6).count
      @monthly_failed_calls = recording_scope.where(date: @start_date..@end_date).where("duration < ?", 40).group_by_month(:date, last: 6).count
    rescue NoMethodError
      # Fallback to manual grouping if groupdate gem is not available
      @monthly_system_calls = group_by_month_manual_for_recordings(recording_scope.where(date: @start_date..@end_date), 6)
      @monthly_successful_calls = group_by_month_manual_for_recordings(recording_scope.where(date: @start_date..@end_date).where("duration >= ?", 120), 6)
      @monthly_failed_calls = group_by_month_manual_for_recordings(recording_scope.where(date: @start_date..@end_date).where("duration < ?", 40), 6)
    end
    
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
    @total_calls_monthly = date_filtered_customers.count
    @calls_connected_percentage_monthly = view_context.calculate_percentage(@calls_connected_count_monthly, @total_calls_monthly)
    
    # WhatsApp metrics
    @whatsapp_conversations_monthly = date_filtered_customers.where(whatsapp_status: ['Message Sent', 'Connected']).count
    
    # Email metrics
    @email_conversations_monthly = date_filtered_customers.where(email_status: ['Email Sent', 'Connected']).count
    
    # LinkedIn metrics
    @linkedin_conversations_monthly = date_filtered_customers.where(linkedin_status: ['Message Sent', 'Conversation Initiated']).count
    
    # User calls report based on Recording model
    @user_call_reports = {}
    
    # If we have a specific user, just get their data
    if user
      # Last day calls
      last_day_recordings = Recording.where(user: user, date: 1.day.ago.beginning_of_day..Time.current.end_of_day)
      last_day_calls = last_day_recordings.count
      last_day_successful_calls = last_day_recordings.where("duration >= ?", 120).count
      last_day_failed_calls = last_day_recordings.where("duration < ?", 40).count
      
      # Last month calls
      last_month_recordings = Recording.where(user: user, date: 1.month.ago.beginning_of_day..Time.current.end_of_day)
      last_month_calls = last_month_recordings.count
      last_month_successful_calls = last_month_recordings.where("duration >= ?", 120).count
      last_month_failed_calls = last_month_recordings.where("duration < ?", 40).count
      
      @user_call_reports[user.id] = {
        name: user.name,
        last_day_calls: last_day_calls,
        last_month_calls: last_month_calls,
        last_day_successful_calls: last_day_successful_calls,
        last_day_failed_calls: last_day_failed_calls,
        last_month_successful_calls: last_month_successful_calls,
        last_month_failed_calls: last_month_failed_calls
      }
    else
      # Get data for all users (exclude admins)
      User.where.not(id: User.joins(:roles).where(roles: { name: 'admin' }).select(:id)).each do |u|
        # Last day calls
        last_day_recordings = Recording.where(user: u, date: 1.day.ago.beginning_of_day..Time.current.end_of_day)
        last_day_calls = last_day_recordings.count
        last_day_successful_calls = last_day_recordings.where("duration >= ?", 120).count
        last_day_failed_calls = last_day_recordings.where("duration < ?", 40).count
        
        # Last month calls
        last_month_recordings = Recording.where(user: u, date: 1.month.ago.beginning_of_day..Time.current.end_of_day)
        last_month_calls = last_month_recordings.count
        last_month_successful_calls = last_month_recordings.where("duration >= ?", 120).count
        last_month_failed_calls = last_month_recordings.where("duration < ?", 40).count
        
        @user_call_reports[u.id] = {
          name: u.name,
          last_day_calls: last_day_calls,
          last_month_calls: last_month_calls,
          last_day_successful_calls: last_day_successful_calls,
          last_day_failed_calls: last_day_failed_calls,
          last_month_successful_calls: last_month_successful_calls,
          last_month_failed_calls: last_month_failed_calls
        }
      end
    end
  end
  
  def prepare_user_progression_metrics
    # Initialize data structure for user progression metrics
    @user_progression_metrics = {}
    
    @users.each do |user|
      # Get counts for each status stage in the progression
      pending_count = Customer.where(user_id: user.id, status: 'Pending').where(created_at: @start_date..@end_date).count
      contact_established_count = Customer.where(user_id: user.id, status: 'Contact Established').where(created_at: @start_date..@end_date).count
      
      # Combined count for Contact Not Established and Unresponsive
      contact_not_established_count = Customer.where(user_id: user.id, status: ['Contact Not Established', 'Unresponsive']).where(created_at: @start_date..@end_date).count
      
      # Get counts for additional statuses
      exhausted_count = Customer.where(user_id: user.id, status: 'Exhausted').where(created_at: @start_date..@end_date).count
      invalid_count = Customer.where(user_id: user.id, status: 'Invalid').where(created_at: @start_date..@end_date).count
      
      # Count deals created by this user
      deals_created_count = Deal.joins(:customer).where(customers: { user_id: user.id }).where(deals: { created_at: @start_date..@end_date }).count
      
      # Count won deals by this user - filter by closing_date
      deals_won_count = Deal.joins(:customer).where(customers: { user_id: user.id }).where(deals: { status: 'won', closing_date: @start_date.to_date..@end_date.to_date }).count
      
      # Store the data in our hash
      @user_progression_metrics[user.id] = {
        'Pending' => pending_count,
        'Contact Established' => contact_established_count,
        'Contact Not Established / Unresponsive' => contact_not_established_count,
        'Exhausted' => exhausted_count,
        'Invalid' => invalid_count,
        'Deals Created' => deals_created_count,
        'Deals Won' => deals_won_count
      }
    end
  end
end
