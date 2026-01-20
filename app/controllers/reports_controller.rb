class ReportsController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :require_admin, only: [:index]

  def index
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

  private

  def require_login
    unless session[:user_id]
      flash[:error] = "You must be logged in to access this section"
      redirect_to root_path
    end
  end
  
  def require_admin
    unless current_user&.admin?
      flash[:error] = "You must be an admin to access reports"
      redirect_to root_path
    end
  end
  
  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
  
  def prepare_team_reports
    @users = User.where.not(id: User.joins(:roles).where(roles: { name: 'admin' }).select(:id))
    
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
      @monthly_deals = Deal.where(created_at: @start_date..@end_date).group_by_month(:created_at, last: 6).count
      @monthly_won_deals = Deal.won.where(created_at: @start_date..@end_date).group_by_month(:created_at, last: 6).count
      @monthly_deal_values = Deal.where(created_at: @start_date..@end_date).group_by_month(:created_at, last: 6).sum(:amount)
    rescue NoMethodError
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
    begin
      @monthly_deals = Deal.assigned_to(user).where(created_at: @start_date..@end_date).group_by_month(:created_at, last: 6).count
      @monthly_won_deals = Deal.assigned_to(user).won.where(closing_date: @start_date.to_date..@end_date.to_date).group_by_month(:closing_date, last: 6).count
      @monthly_deal_values = Deal.assigned_to(user).where(created_at: @start_date..@end_date).group_by_month(:created_at, last: 6).sum(:amount)
    rescue NoMethodError
      @monthly_deals = group_by_month_manual(Deal.assigned_to(user).where(created_at: @start_date..@end_date), 6)
      @monthly_won_deals = group_by_month_manual(Deal.assigned_to(user).won.where(closing_date: @start_date.to_date..@end_date.to_date), 6)
      @monthly_deal_values = group_by_month_manual_sum(Deal.assigned_to(user).where(created_at: @start_date..@end_date), :amount, 6)
    end
    
    prepare_sales_rep_metrics(user)
    prepare_communication_metrics(user)
    
    # Prepare individual progression metrics
    @user_progression_metrics = {}
    pending_count = Customer.where(user_id: user.id, status: 'Pending').where(created_at: @start_date..@end_date).count
    contact_established_count = Customer.where(user_id: user.id, status: 'Contact Established').where(created_at: @start_date..@end_date).count
    contact_not_established_count = Customer.where(user_id: user.id, status: ['Contact Not Established', 'Unresponsive']).where(created_at: @start_date..@end_date).count
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
    
    date_filtered_customers = customer_scope.where(created_at: @start_date..@end_date)
    date_filtered_deals = deal_scope.where(created_at: @start_date..@end_date)
    
    @total_assigned_leads = date_filtered_customers.count
    @lead_source_distribution = date_filtered_customers.group(:lead_source).count
    
    cleaned_lead_source_distribution = {}
    @lead_source_distribution.each do |source, count|
      key = source.presence || "Unknown"
      cleaned_lead_source_distribution[key] = count
    end
    @lead_source_distribution = cleaned_lead_source_distribution
    
    @total_deals = date_filtered_deals.count
    @deal_stage_distribution = date_filtered_deals.joins(:deal_stage).group('deal_stages.name').count
    @total_deal_value = date_filtered_deals.sum(:amount)
    
    @total_won_deals = deal_scope.won.where(closing_date: @start_date.to_date..@end_date.to_date).count
    @total_won_deal_value = deal_scope.won.where(closing_date: @start_date.to_date..@end_date.to_date).sum(:amount)
    @total_lost_deals = deal_scope.lost.where(closing_date: @start_date.to_date..@end_date.to_date).count
    @total_lost_deal_value = deal_scope.lost.where(closing_date: @start_date.to_date..@end_date.to_date).sum(:amount)
    
    recording_scope = user ? Recording.where(user: user) : Recording
    @total_system_calls = recording_scope.where(date: @start_date..@end_date).count
    
    @connection_established_percentage = calculate_percentage(date_filtered_customers.where(status: 'Contact Established').count, @total_assigned_leads)
    @not_interested_percentage = calculate_percentage(date_filtered_customers.where(status: 'Not Interested').count, @total_assigned_leads)
    @discovery_call_booked_percentage = calculate_percentage(date_filtered_customers.where(status: 'Proposal Sent').count, @total_assigned_leads)
    @unresponsive_percentage = calculate_percentage(date_filtered_customers.where(status: 'Unresponsive').count, @total_assigned_leads)
    @conversion_count = date_filtered_customers.where(status: 'Converted').count
    @conversion_percentage = calculate_percentage(@conversion_count, @total_assigned_leads)
  end
  
  def prepare_communication_metrics(user)
    customer_scope = user ? Customer.where(user_id: user.id) : Customer
    date_filtered_customers = customer_scope.where(created_at: @start_date..@end_date)
    
    recording_scope = user ? Recording.where(user: user) : Recording
    date_filtered_recordings = recording_scope.where(date: @start_date..@end_date)
    
    @successful_calls_count = date_filtered_recordings.where("duration >= ?", 120).count
    @failed_calls_count = date_filtered_recordings.where("duration < ?", 40).count
    @attempted_calls_count = date_filtered_recordings.where("duration >= ? AND duration < ?", 40, 120).count
    @successful_calls_percentage = calculate_percentage(@successful_calls_count, @total_system_calls)
    
    begin
      @monthly_system_calls = recording_scope.where(date: @start_date..@end_date).group_by_month(:date, last: 6).count
      @monthly_successful_calls = recording_scope.where(date: @start_date..@end_date).where("duration >= ?", 120).group_by_month(:date, last: 6).count
      @monthly_failed_calls = recording_scope.where(date: @start_date..@end_date).where("duration < ?", 40).group_by_month(:date, last: 6).count
    rescue NoMethodError
      @monthly_system_calls = group_by_month_manual_for_recordings(recording_scope.where(date: @start_date..@end_date), 6)
      @monthly_successful_calls = group_by_month_manual_for_recordings(recording_scope.where(date: @start_date..@end_date).where("duration >= ?", 120), 6)
      @monthly_failed_calls = group_by_month_manual_for_recordings(recording_scope.where(date: @start_date..@end_date).where("duration < ?", 40), 6)
    end
    
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
    @calls_connected_percentage_monthly = calculate_percentage(@calls_connected_count_monthly, @total_calls_monthly)
    
    @whatsapp_conversations_monthly = date_filtered_customers.where(whatsapp_status: ['Message Sent', 'Connected']).count
    @email_conversations_monthly = date_filtered_customers.where(email_status: ['Email Sent', 'Connected']).count
    @linkedin_conversations_monthly = date_filtered_customers.where(linkedin_status: ['Message Sent', 'Conversation Initiated']).count
    
    @user_call_reports = {}
    
    if user
      last_day_recordings = Recording.where(user: user, date: 1.day.ago.beginning_of_day..Time.current.end_of_day)
      last_day_calls = last_day_recordings.count
      last_day_successful_calls = last_day_recordings.where("duration >= ?", 120).count
      last_day_failed_calls = last_day_recordings.where("duration < ?", 40).count
      
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
      User.where.not(id: User.joins(:roles).where(roles: { name: 'admin' }).select(:id)).each do |u|
        last_day_recordings = Recording.where(user: u, date: 1.day.ago.beginning_of_day..Time.current.end_of_day)
        last_day_calls = last_day_recordings.count
        last_day_successful_calls = last_day_recordings.where("duration >= ?", 120).count
        last_day_failed_calls = last_day_recordings.where("duration < ?", 40).count
        
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
    @user_progression_metrics = {}
    
    @users.each do |user|
      pending_count = Customer.where(user_id: user.id, status: 'Pending').where(created_at: @start_date..@end_date).count
      contact_established_count = Customer.where(user_id: user.id, status: 'Contact Established').where(created_at: @start_date..@end_date).count
      contact_not_established_count = Customer.where(user_id: user.id, status: ['Contact Not Established', 'Unresponsive']).where(created_at: @start_date..@end_date).count
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
  end

  def calculate_percentage(numerator, denominator)
    denominator.to_i > 0 ? (numerator.to_f / denominator * 100).round(2) : 0
  end
  
  def group_by_month_manual(scope, months_count)
    result = {}
    end_date = Date.today.end_of_month
    start_date = (end_date - (months_count - 1).months).beginning_of_month
    
    current_date = start_date
    while current_date <= end_date
      result[current_date] = 0
      current_date = current_date.next_month
    end
    
    scope.where(created_at: start_date.beginning_of_day..end_date.end_of_day).each do |record|
      month_start = Date.new(record.created_at.year, record.created_at.month, 1)
      result[month_start] += 1 if result.key?(month_start)
    end
    
    result
  end
  
  def group_by_month_manual_sum(scope, field, months_count)
    result = {}
    end_date = Date.today.end_of_month
    start_date = (end_date - (months_count - 1).months).beginning_of_month
    
    current_date = start_date
    while current_date <= end_date
      result[current_date] = 0
      current_date = current_date.next_month
    end
    
    scope.where(created_at: start_date.beginning_of_day..end_date.end_of_day).each do |record|
      month_start = Date.new(record.created_at.year, record.created_at.month, 1)
      result[month_start] += record.send(field) if result.key?(month_start)
    end
    
    result
  end
  
  def group_by_month_manual_for_recordings(scope, months_count)
    result = {}
    end_date = Date.today.end_of_month
    start_date = (end_date - (months_count - 1).months).beginning_of_month
    
    current_date = start_date
    while current_date <= end_date
      result[current_date] = 0
      current_date = current_date.next_month
    end
    
    scope.where(date: start_date.beginning_of_day..end_date.end_of_day).each do |record|
      month_start = Date.new(record.date.year, record.date.month, 1)
      result[month_start] += 1 if result.key?(month_start)
    end
    
    result
  end
end
