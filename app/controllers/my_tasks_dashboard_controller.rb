class MyTasksDashboardController < ApplicationController
  layout 'dashboard'
  before_action :require_login

  def index
    # Redirect to the my_tasks page in tasks controller
    redirect_to my_tasks_tasks_path(status: 'pending')
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