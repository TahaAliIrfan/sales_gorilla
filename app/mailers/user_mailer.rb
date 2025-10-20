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

    subject_line = "WhatsApp Messages: #{@customer.name}"
    
    mail(
      to: @user.email,
      subject: subject_line
    )
  end
end 