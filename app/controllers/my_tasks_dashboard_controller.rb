class MyTasksDashboardController < ApplicationController
  layout 'dashboard'
  before_action :require_login

  def index
    # Get tasks data for the current user
    @pending_tasks_count = current_user.tasks.pending.count
    @today_tasks_count = current_user.tasks.for_today.count
    @overdue_tasks_count = current_user.tasks.overdue.count
    @completed_tasks_count = current_user.tasks.completed.count
    
    # Get today's tasks for the current user
    @today_tasks = current_user.tasks.for_today.order(due_date: :asc).limit(10)
    
    # Get overdue tasks for the current user
    @overdue_tasks = current_user.tasks.overdue.order(due_date: :asc).limit(10)
    
    # Get pending tasks for the current user
    @pending_tasks = current_user.tasks.pending.order(due_date: :asc).limit(10)
    
    # Get recently completed tasks for the current user
    @recently_completed_tasks = current_user.tasks.completed.order(updated_at: :desc).limit(5)
    
    # Get high priority tasks that need immediate attention
    @high_priority_tasks = current_user.tasks.where(priority: 'High', status: ['pending', 'in_progress']).order(due_date: :asc).limit(5)
    
    # Get tasks by priority for charts
    @tasks_by_priority = {
      'Low' => current_user.tasks.where(priority: 'Low').count,
      'Medium' => current_user.tasks.where(priority: 'Medium').count,
      'High' => current_user.tasks.where(priority: 'High').count
    }
    
    # Get tasks by status for charts
    @tasks_by_status = {
      'Pending' => current_user.tasks.pending.count,
      'In Progress' => current_user.tasks.in_progress.count,
      'Completed' => current_user.tasks.completed.count,
      'Cancelled' => current_user.tasks.cancelled.count
    }
    
    # Count recently completed tasks (last 7 days)
    @recent_completions_count = current_user.tasks.completed.where('updated_at >= ?', 7.days.ago).count
    
    # Get filtered tasks based on selected tab
    @filtered_tasks = case params[:tab]
                      when 'pending'
                        current_user.tasks.pending.order(due_date: :asc).limit(10)
                      when 'in_progress'
                        current_user.tasks.in_progress.order(due_date: :asc).limit(10)
                      when 'completed'
                        current_user.tasks.completed.order(updated_at: :desc).limit(10)
                      when 'cancelled'
                        current_user.tasks.cancelled.order(updated_at: :desc).limit(10)
                      else
                        # Default to pending tasks if no tab is specified
                        params[:tab] = 'pending'
                        current_user.tasks.pending.order(due_date: :asc).limit(10)
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