class ManagerController < ApplicationController
  before_action :authenticate_user!
  before_action :require_manager
  layout 'dashboard'
  
  def dashboard
    @associates = current_user.associates
    
    # Basic metrics for each associate
    @associate_metrics = {}
    
    @associates.each do |associate|
      # Get data for the last 30 days
      start_date = 30.days.ago.beginning_of_day
      end_date = Date.current.end_of_day
      
      customers_count = associate.customers.count
      new_customers = associate.customers.where("created_at >= ?", start_date).count
      recent_activities = CustomerActivity.where(user_id: associate.id)
                                         .where("created_at >= ?", start_date)
                                         .count
      recordings_count = associate.recordings.where("date >= ?", start_date).count
      
      # Get tasks metrics
      completed_tasks = associate.tasks.where(completed: true)
                                .where("updated_at >= ?", start_date)
                                .count
      pending_tasks = associate.tasks.where(completed: false).count
      overdue_tasks = associate.tasks.where(completed: false)
                               .where("due_date < ?", Date.current)
                               .count
      
      # Get deals metrics
      active_deals = associate.deals.where.not(status: ['won', 'lost']).count
      won_deals = associate.deals.where(status: 'won')
                           .where("updated_at >= ?", start_date)
                           .count
      deal_value = associate.deals.where(status: 'won')
                            .where("updated_at >= ?", start_date)
                            .sum(:amount)
      
      @associate_metrics[associate.id] = {
        name: associate.name,
        customers_count: customers_count,
        new_customers: new_customers,
        recent_activities: recent_activities,
        recordings_count: recordings_count,
        completed_tasks: completed_tasks,
        pending_tasks: pending_tasks,
        overdue_tasks: overdue_tasks,
        active_deals: active_deals,
        won_deals: won_deals,
        deal_value: deal_value
      }
    end
    
    # Summary metrics for all associates
    @total_customers = @associates.sum { |a| a.customers.count }
    @total_new_customers = @associates.sum { |a| a.customers.where("created_at >= ?", 30.days.ago).count }
    @total_recordings = @associates.sum { |a| a.recordings.where("date >= ?", 30.days.ago).count }
    @total_active_deals = @associates.sum { |a| a.deals.where.not(status: ['won', 'lost']).count }
    @total_won_deals = @associates.sum { |a| a.deals.where(status: 'won').where("updated_at >= ?", 30.days.ago).count }
    @total_deal_value = @associates.sum { |a| a.deals.where(status: 'won').where("updated_at >= ?", 30.days.ago).sum(:amount) }
  end


  private
  
  def authenticate_user!
    unless session[:user_id]
      redirect_to signin_path, alert: "Please sign in to access this page."
    end
  end
  
  def require_manager
    unless current_user&.manager? || current_user&.admin?
      redirect_to dashboard_path, alert: "You don't have permission to access the manager dashboard."
    end
  end
  
  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
end
