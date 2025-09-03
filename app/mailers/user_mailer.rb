class UserMailer < ApplicationMailer
  default from: 'crm@tecaudex.com'

  # Send an email to a user when they are assigned a customer/lead
  def customer_assignment_notification(user, customer)
    @user = user
    @customer = customer
    
    mail(
      to: @user.email,
      subject: "You have been assigned a new Lead"
    )
  end

  def whatsapp_message_notification(user, customer, message_preview)
    
    @user = user
    @customer = customer
    @message_preview = message_preview
    
    # Create thread identifiers for proper email threading
    # Use a consistent thread ID based on customer and user to group all WhatsApp messages
    thread_id = "whatsapp-thread-#{@customer.id}-#{@user.id}@tecaudex.com"
    message_id = "whatsapp-msg-#{@customer.id}-#{Time.current.to_i}-#{SecureRandom.hex(4)}@tecaudex.com"
    
    # Use consistent subject line to help email clients group messages
    subject_line = "WhatsApp Messages: #{@customer.name}"
    
    mail(
      to: @user.email,
      subject: subject_line,
      'Message-ID' => message_id,
      'In-Reply-To' => thread_id,
      'References' => thread_id
    )
  end
end 