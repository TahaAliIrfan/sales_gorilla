class UserMailer < ApplicationMailer
  default from: "crm@tecaudex.com"

  # Send an email to a user when they are assigned a customer/lead
  def customer_assignment_notification(user, customer)
    @user = user
    @customer = customer

    mail(
      to: @user.email,
      subject: "You have been assigned a new Lead"
    )
  end

  def whatsapp_message_notification(email, customer = nil, message_preview)
    @email = email
    @customer = customer
    @message_preview = message_preview

    if customer.present? && customer.name.present?
      subject_line = "WhatsApp Messages: #{@customer.name}"
    else
      subject_line = "NEW Client has messaged you"
    end

    mail(
      to: @email,
      subject: subject_line
    )
  end

  def whatsapp_call_notification(email, customer = nil, message_preview = "'Client has called us on whatsapp")
    @email = email
    @customer = customer
    @message_preview = message_preview

    if customer.name.present?
      subject_line = "Client #{@customer.name} is calling you"
    else
      subject_line = "NEW Client is calling you"
    end

    mail(
      to: @email,
      subject: subject_line
    )
  end
end
