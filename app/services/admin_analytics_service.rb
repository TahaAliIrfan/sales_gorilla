class AdminAnalyticsService
  def initialize(start_date: 30.days.ago, end_date: Time.current, user_id: nil)
    @start_date = start_date.beginning_of_day
    @end_date = end_date.end_of_day
    @user_id = user_id
  end

  def user_performance_summary
    if @user_id.present?
      users = [User.find(@user_id)]
    else
      users = User.where.not(id: User.joins(:roles).where(roles: { name: 'admin' }).select(:id))
                  .includes(:deals, :customers, :tasks, :recordings)
    end

    users.map do |user|
      {
        id: user.id,
        name: user.name || 'Unknown User',
        email: user.email,
        role: user.highest_role&.name || 'No Role',
        daily_metrics: calculate_daily_metrics(user),
        weekly_metrics: calculate_weekly_metrics(user),
        monthly_metrics: calculate_monthly_metrics(user),
        performance_score: calculate_performance_score(user),
        whatsapp_conversations: calculate_whatsapp_conversations(user),
        active_whatsapp_conversations: calculate_active_whatsapp_conversations(user),
        connected_calls: Recording.where(user: user, date: @start_date..@end_date).where("duration >= ?", 120).count
      }
    end
  end

  def team_performance_overview
    non_admin_users = User.where.not(id: User.joins(:roles).where(roles: { name: 'admin' }).select(:id))
    {
      total_users: non_admin_users.count,
      active_users: non_admin_users.joins(:customers).where(customers: { updated_at: @start_date..@end_date }).distinct.count,
      total_deals: Deal.where(created_at: @start_date..@end_date).count,
      total_revenue: Deal.won.where(closing_date: @start_date.to_date..@end_date.to_date).sum(:amount),
      conversion_rate: calculate_team_conversion_rate,
      total_whatsapp_conversations: calculate_total_whatsapp_conversations,
      total_active_conversations: calculate_total_active_conversations,
      top_performers: get_top_performers
    }
  end

  def activity_trends
    {
      daily_activities: calculate_daily_activities,
      weekly_activities: calculate_weekly_activities,
      monthly_activities: calculate_monthly_activities
    }
  end

  def deal_pipeline_analytics
    {
      deals_by_stage: Deal.joins(:deal_stage)
                         .where(created_at: @start_date..@end_date)
                         .group('deal_stages.name')
                         .count,
      deals_by_user: Deal.joins(:user)
                        .where(created_at: @start_date..@end_date)
                        .group('users.name')
                        .count,
      average_deal_size: Deal.where(created_at: @start_date..@end_date).average(:amount)&.to_f || 0,
      deal_velocity: calculate_deal_velocity
    }
  end

  def communication_analytics
    users_data = {}
    
    if @user_id.present?
      users = [User.find(@user_id)]
    else
      users = User.where.not(id: User.joins(:roles).where(roles: { name: 'admin' }).select(:id))
    end
    
    users.each do |user|
      users_data[user.id] = {
        name: user.name || 'Unknown User',
        calls_made: Recording.where(user: user, date: @start_date..@end_date).count,
        successful_calls: Recording.where(user: user, date: @start_date..@end_date)
                                  .where("duration >= ?", 120).count,
        customers_contacted: Customer.where(user: user, updated_at: @start_date..@end_date)
                                   .where.not(call_status: 'Pending').count,
        deals_created: Deal.where(user: user, created_at: @start_date..@end_date).count,
        deals_won: Deal.where(user: user, status: 'won', closing_date: @start_date.to_date..@end_date.to_date).count,
        whatsapp_conversations: calculate_whatsapp_conversations(user),
        active_whatsapp_conversations: calculate_active_whatsapp_conversations(user)
      }
    end
    
    users_data
  end

  private

  def calculate_daily_metrics(user)
    today = Date.current
    yesterday = today - 1.day
    
    {
      today: {
        calls: Recording.where(user: user, date: today.beginning_of_day..today.end_of_day).count,
        tasks_completed: user.tasks.where(status: 'completed', updated_at: today.beginning_of_day..today.end_of_day).count,
        customers_contacted: Customer.where(user: user, updated_at: today.beginning_of_day..today.end_of_day)
                                   .where.not(call_status: 'Pending').count,
        deals_created: user.deals.where(created_at: today.beginning_of_day..today.end_of_day).count
      },
      yesterday: {
        calls: Recording.where(user: user, date: yesterday.beginning_of_day..yesterday.end_of_day).count,
        tasks_completed: user.tasks.where(status: 'completed', updated_at: yesterday.beginning_of_day..yesterday.end_of_day).count,
        customers_contacted: Customer.where(user: user, updated_at: yesterday.beginning_of_day..yesterday.end_of_day)
                                   .where.not(call_status: 'Pending').count,
        deals_created: user.deals.where(created_at: yesterday.beginning_of_day..yesterday.end_of_day).count
      }
    }
  end

  def calculate_weekly_metrics(user)
    this_week_start = Date.current.beginning_of_week
    this_week_end = Date.current.end_of_week
    last_week_start = this_week_start - 1.week
    last_week_end = this_week_end - 1.week
    
    {
      this_week: {
        calls: Recording.where(user: user, date: this_week_start..this_week_end).count,
        successful_calls: Recording.where(user: user, date: this_week_start..this_week_end)
                                  .where("duration >= ?", 120).count,
        tasks_completed: user.tasks.where(status: 'completed', updated_at: this_week_start..this_week_end).count,
        customers_contacted: Customer.where(user: user, updated_at: this_week_start..this_week_end)
                                   .where.not(call_status: 'Pending').count,
        deals_created: user.deals.where(created_at: this_week_start..this_week_end).count,
        deals_won: user.deals.where(status: 'won', closing_date: this_week_start.to_date..this_week_end.to_date).count,
        revenue_generated: user.deals.where(status: 'won', closing_date: this_week_start.to_date..this_week_end.to_date).sum(:amount)
      },
      last_week: {
        calls: Recording.where(user: user, date: last_week_start..last_week_end).count,
        successful_calls: Recording.where(user: user, date: last_week_start..last_week_end)
                                  .where("duration >= ?", 120).count,
        tasks_completed: user.tasks.where(status: 'completed', updated_at: last_week_start..last_week_end).count,
        customers_contacted: Customer.where(user: user, updated_at: last_week_start..last_week_end)
                                   .where.not(call_status: 'Pending').count,
        deals_created: user.deals.where(created_at: last_week_start..last_week_end).count,
        deals_won: user.deals.where(status: 'won', closing_date: last_week_start.to_date..last_week_end.to_date).count,
        revenue_generated: user.deals.where(status: 'won', closing_date: last_week_start.to_date..last_week_end.to_date).sum(:amount)
      }
    }
  end

  def calculate_monthly_metrics(user)
    this_month_start = Date.current.beginning_of_month
    this_month_end = Date.current.end_of_month
    last_month_start = this_month_start - 1.month
    last_month_end = this_month_end - 1.month
    
    {
      this_month: {
        calls: Recording.where(user: user, date: this_month_start..this_month_end).count,
        successful_calls: Recording.where(user: user, date: this_month_start..this_month_end)
                                  .where("duration >= ?", 120).count,
        tasks_completed: user.tasks.where(status: 'completed', updated_at: this_month_start..this_month_end).count,
        customers_contacted: Customer.where(user: user, updated_at: this_month_start..this_month_end)
                                   .where.not(call_status: 'Pending').count,
        deals_created: user.deals.where(created_at: this_month_start..this_month_end).count,
        deals_won: user.deals.where(status: 'won', closing_date: this_month_start.to_date..this_month_end.to_date).count,
        revenue_generated: user.deals.where(status: 'won', closing_date: this_month_start.to_date..this_month_end.to_date).sum(:amount),
        customers_converted: Customer.where(user: user, status: 'Converted', updated_at: this_month_start..this_month_end).count
      },
      last_month: {
        calls: Recording.where(user: user, date: last_month_start..last_month_end).count,
        successful_calls: Recording.where(user: user, date: last_month_start..last_month_end)
                                  .where("duration >= ?", 120).count,
        tasks_completed: user.tasks.where(status: 'completed', updated_at: last_month_start..last_month_end).count,
        customers_contacted: Customer.where(user: user, updated_at: last_month_start..last_month_end)
                                   .where.not(call_status: 'Pending').count,
        deals_created: user.deals.where(created_at: last_month_start..last_month_end).count,
        deals_won: user.deals.where(status: 'won', closing_date: last_month_start.to_date..last_month_end.to_date).count,
        revenue_generated: user.deals.where(status: 'won', closing_date: last_month_start.to_date..last_month_end.to_date).sum(:amount),
        customers_converted: Customer.where(user: user, status: 'Converted', updated_at: last_month_start..last_month_end).count
      }
    }
  end

  def calculate_performance_score(user)
    monthly_metrics = calculate_monthly_metrics(user)
    this_month = monthly_metrics[:this_month]
    
    # Calculate performance score based on various factors (out of 100)
    score = 0
    
    # Connected calls (calls above 120 sec) - 25 points max
    connected_calls = Recording.where(user: user, date: Date.current.beginning_of_month..Date.current.end_of_month)
                               .where("duration >= ?", 120).count
    connected_calls_score = [connected_calls * 3, 25].min
    score += connected_calls_score
    
    # Regular calls made (15 points max)
    calls_score = [this_month[:calls] * 1, 15].min
    score += calls_score
    
    # WhatsApp conversations (15 points max)
    whatsapp_conversations = calculate_whatsapp_conversations(user)
    whatsapp_score = [whatsapp_conversations * 2, 15].min
    score += whatsapp_score
    
    # Active WhatsApp conversations (15 points max)
    active_conversations = calculate_active_whatsapp_conversations(user)
    active_whatsapp_score = [active_conversations * 3, 15].min
    score += active_whatsapp_score
    
    # Deals won (20 points max)
    deals_score = [this_month[:deals_won] * 4, 20].min
    score += deals_score
    
    # Task completion (10 points max)
    tasks_score = [this_month[:tasks_completed] * 1, 10].min
    score += tasks_score
    
    score.round
  end

  def calculate_team_conversion_rate
    total_customers = Customer.where(created_at: @start_date..@end_date).count
    converted_customers = Customer.where(status: 'Converted', updated_at: @start_date..@end_date).count
    
    return 0 if total_customers.zero?
    
    ((converted_customers.to_f / total_customers) * 100).round(2)
  end

  def get_top_performers(limit = 5)
    non_admin_users = User.where.not(id: User.joins(:roles).where(roles: { name: 'admin' }).select(:id))
    non_admin_users.map do |user|
      {
        id: user.id,
        name: user.name || 'Unknown User',
        deals_won: user.deals.where(status: 'won', closing_date: @start_date.to_date..@end_date.to_date).count,
        revenue: user.deals.where(status: 'won', closing_date: @start_date.to_date..@end_date.to_date).sum(:amount),
        score: calculate_performance_score(user)
      }
    end.sort_by { |u| -u[:score] }.first(limit)
  end

  def calculate_daily_activities
    activities = {}
    (@start_date.to_date..@end_date.to_date).each do |date|
      activities[date] = {
        calls: Recording.where(date: date.beginning_of_day..date.end_of_day).count,
        tasks_completed: Task.where(status: 'completed', updated_at: date.beginning_of_day..date.end_of_day).count,
        deals_created: Deal.where(created_at: date.beginning_of_day..date.end_of_day).count,
        customers_contacted: Customer.where(updated_at: date.beginning_of_day..date.end_of_day)
                                   .where.not(call_status: 'Pending').count
      }
    end
    activities
  end

  def calculate_weekly_activities
    activities = {}
    start_week = @start_date.to_date.beginning_of_week
    end_week = @end_date.to_date.end_of_week
    current_week = start_week
    
    while current_week <= end_week
      week_end = [current_week.end_of_week, @end_date.to_date].min
      activities[current_week] = {
        calls: Recording.where(date: current_week.beginning_of_day..week_end.end_of_day).count,
        tasks_completed: Task.where(status: 'completed', updated_at: current_week.beginning_of_day..week_end.end_of_day).count,
        deals_created: Deal.where(created_at: current_week.beginning_of_day..week_end.end_of_day).count,
        customers_contacted: Customer.where(updated_at: current_week.beginning_of_day..week_end.end_of_day)
                                   .where.not(call_status: 'Pending').count
      }
      current_week = current_week.next_week
    end
    activities
  end

  def calculate_monthly_activities
    activities = {}
    start_month = @start_date.to_date.beginning_of_month
    end_month = @end_date.to_date.end_of_month
    current_month = start_month
    
    while current_month <= end_month
      month_end = [current_month.end_of_month, @end_date.to_date].min
      activities[current_month] = {
        calls: Recording.where(date: current_month.beginning_of_day..month_end.end_of_day).count,
        tasks_completed: Task.where(status: 'completed', updated_at: current_month.beginning_of_day..month_end.end_of_day).count,
        deals_created: Deal.where(created_at: current_month.beginning_of_day..month_end.end_of_day).count,
        customers_contacted: Customer.where(updated_at: current_month.beginning_of_day..month_end.end_of_day)
                                   .where.not(call_status: 'Pending').count,
        deals_won: Deal.where(status: 'won', closing_date: current_month.to_date..month_end.to_date).count,
        revenue: Deal.where(status: 'won', closing_date: current_month.to_date..month_end.to_date).sum(:amount)
      }
      current_month = current_month.next_month
    end
    activities
  end

  def calculate_deal_velocity
    won_deals = Deal.won.where(closing_date: @start_date.to_date..@end_date.to_date)
    return 0 if won_deals.empty?
    
    total_days = won_deals.sum { |deal| (deal.closing_date - deal.created_at.to_date).to_i }
    average_days = total_days / won_deals.count
    average_days
  end

  def calculate_whatsapp_conversations(user)
    # Count unique customers that had WhatsApp messages sent to them
    Customer.joins(:whatsapp_messages)
            .where(user: user)
            .where(whatsapp_messages: { 
              timestamp: @start_date..@end_date, 
              direction: 'outbound' 
            })
            .distinct
            .count
  end

  def calculate_active_whatsapp_conversations(user)
    # Count conversations where customer replied back
    Customer.joins(:whatsapp_messages)
            .where(user: user)
            .where(whatsapp_messages: { timestamp: @start_date..@end_date })
            .group('customers.id')
            .having('COUNT(CASE WHEN whatsapp_messages.direction = ? THEN 1 END) > 0 AND COUNT(CASE WHEN whatsapp_messages.direction = ? THEN 1 END) > 0', 'outbound', 'inbound')
            .count
            .size
  end

  def calculate_total_whatsapp_conversations
    # Count unique customers that had WhatsApp messages sent to them (excluding admin users)
    non_admin_users = User.where.not(id: User.joins(:roles).where(roles: { name: 'admin' }).select(:id))
    Customer.joins(:whatsapp_messages)
            .where(user: non_admin_users)
            .where(whatsapp_messages: { 
              timestamp: @start_date..@end_date, 
              direction: 'outbound' 
            })
            .distinct
            .count
  end

  def calculate_total_active_conversations
    # Count total conversations where customers replied back (excluding admin users)
    non_admin_users = User.where.not(id: User.joins(:roles).where(roles: { name: 'admin' }).select(:id))
    Customer.joins(:whatsapp_messages)
            .where(user: non_admin_users)
            .where(whatsapp_messages: { timestamp: @start_date..@end_date })
            .group('customers.id')
            .having('COUNT(CASE WHEN whatsapp_messages.direction = ? THEN 1 END) > 0 AND COUNT(CASE WHEN whatsapp_messages.direction = ? THEN 1 END) > 0', 'outbound', 'inbound')
            .count
            .size
  end
end