class ApplicationController < ActionController::Base
  include Pundit::Authorization
  
  helper_method :current_user, :current_user_admin?
  
  # Rescue from common exceptions
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  
  private
  
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  
  def current_user_admin?
    current_user&.admin?
  end

  
  def require_login
    unless current_user
      flash[:error] = "You must be logged in to access this section"
      redirect_to root_path
    end
  end
  
  def require_admin
    unless current_user_admin?
      flash[:error] = "You don't have permission to access this section"
      redirect_to customers_path
    end
  end
  
  def handle_validation_error(exception)
    Rails.logger.error("Validation error: #{exception.message}")
    flash[:error] = "Validation error: #{exception.message}"
    redirect_back(fallback_location: root_path)
  end
  
  def handle_record_not_found(exception)
    Rails.logger.error("Record not found: #{exception.message}")
    flash[:error] = "The requested record could not be found."
    redirect_to root_path
  end
  
  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    flash[:error] = "You are not authorized to perform this action."
    redirect_to(request.referrer || root_path)
  end
end
