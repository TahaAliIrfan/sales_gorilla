class DashboardController < ApplicationController
  layout 'dashboard'
  before_action :require_login

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
end
