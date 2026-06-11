class CustomerAssignmentNotificationWorker
  include Sidekiq::Worker
  
  sidekiq_options retry: 3, queue: 'notifications'
  
  def perform(user_id, customer_id, skip_email = false)
    # Find the user and customer
    user = User.find_by(id: user_id)
    customer = Customer.find_by(id: customer_id)

    # Return early if user or customer not found
    return unless user && customer

    # Create notification
    Notification.create!(
      user_id: user.id,
      content: "You have been assigned a new lead: #{customer.name}",
      notification_type: 'system',
      resource: customer,
      read: false
    )

    # Skip the email (but keep the in-app notification) when requested,
    # e.g. during bulk assignment.
    return if skip_email

    # Send email notification
    begin
      UserMailer.customer_assignment_notification(user, customer).deliver_now
      
      # Log successful notification
      Rails.logger.info "Successfully sent assignment notification to user #{user.email} for customer #{customer.name}"
    rescue => e
      # Log error
      Rails.logger.error "Failed to send assignment email to user #{user.email}: #{e.message}"
    end
  end
end 