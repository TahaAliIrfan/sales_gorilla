class NotificationsController < ApplicationController
  before_action :require_login
  before_action :set_notification, only: [:show, :mark_as_read]
  
  def index
    @notifications = current_user.notifications.recent
  end
  
  def show
    # Mark the notification as read when viewed
    @notification.mark_as_read! unless @notification.read?
    
    # Redirect to the appropriate resource based on notification type
    redirect_to determine_redirect_path
  end
  
  def mark_as_read
    @notification.mark_as_read!
    
    respond_to do |format|
      format.html { redirect_back(fallback_location: notifications_path, notice: "Notification marked as read.") }
      format.json { render json: { success: true } }
    end
  end
  
  def mark_all_as_read
    current_user.mark_all_notifications_as_read!
    
    respond_to do |format|
      format.html { redirect_back(fallback_location: notifications_path, notice: "All notifications marked as read.") }
      format.json { render json: { success: true } }
    end
  end
  
  private
  
  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
  
  def determine_redirect_path
    if @notification.resource.present?
      case @notification.notification_type
      when 'message'
        if @notification.resource.is_a?(WhatsappMessage)
          # Redirect to the chat with this customer
          customer = @notification.resource.customer
          return customer_path(customer, anchor: 'messages')
        end
      when 'task'
        if @notification.resource.is_a?(Task)
          # Redirect to the task
          return task_path(@notification.resource)
        end
      when 'deal'
        if @notification.resource.is_a?(Deal)
          # Redirect to the deal
          return deal_path(@notification.resource)
        end
      end
    end
    
    # Default fallback
    notifications_path
  end
end
