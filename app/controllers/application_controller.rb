class ApplicationController < ActionController::Base
  helper_method :current_user
  
  # Rescue from common exceptions
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
  
  private
  
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
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
end
