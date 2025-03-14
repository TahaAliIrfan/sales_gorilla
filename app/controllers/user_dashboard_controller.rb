class UserDashboardController < ApplicationController
  layout 'dashboard'
  before_action :require_login

  def index
    # Get deals for the current user
    @my_deals = current_user ? Deal.assigned_to(current_user).active.order(expected_close_date: :asc).limit(5) : []
    
    # Get customers assigned to the current user
    @my_customers = current_user ? Customer.where(user_id: current_user.id).order(created_at: :desc).limit(5) : []
    
    # Get deals by stage for the current user
    @deal_stages = DealStage.all
    @my_deals_by_stage = {}
    @deal_stages.each do |stage|
      @my_deals_by_stage[stage.id] = Deal.active.assigned_to(current_user).by_stage(stage).count
    end
    
    # Check for deals and customers that need attention
    @deals_needing_attention = deals_needing_attention
    @customers_needing_attention = customers_needing_attention
    @needs_attention = @deals_needing_attention.any? || @customers_needing_attention.any?
    
    # User performance metrics
    @total_deals = Deal.assigned_to(current_user).count
    @active_deals = Deal.assigned_to(current_user).active.count
    @won_deals = Deal.assigned_to(current_user).won.count
    @lost_deals = Deal.assigned_to(current_user).lost.count
    @total_deal_value = Deal.assigned_to(current_user).sum(:amount)
    @won_deal_value = Deal.assigned_to(current_user).won.sum(:amount)
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