class DevLoginController < ApplicationController
  # Skip common before actions to avoid dependencies
  skip_before_action :set_tasks_notification_counts
  skip_before_action :set_notification_counts
  #before_action :development_only!
  
  def show
    # Show the development login form
  end
  
  def create
    email = params[:email]&.strip&.downcase
    
    if email.blank?
      flash.now[:error] = "Please enter an email address"
      render :show
      return
    end
    
    # Find or create user by email
    user = User.find_by(email: email)
    
    if user.nil?
      flash.now[:error] = "User with email '#{email}' not found. Available users: #{User.pluck(:email).join(', ')}"
      render :show
      return
    end
    
    # Log in the user
    session[:user_id] = user.id
    
    # Redirect to dashboard
    redirect_to dashboard_path, notice: "Development login successful! Logged in as #{user.email}"
  end
  
  private
  
  def development_only!
    unless Rails.env.development?
      raise ActionController::RoutingError.new('Not Found')
    end
  end
end