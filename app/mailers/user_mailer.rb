class UserMailer < ApplicationMailer
  default from: "reply@salesgorilla.app"

  # Invitation for a brand-new account: includes a set-password link so the
  # recipient can finish joining the organization.
  def organization_invitation(user, organization, inviter, reset_token)
    @user         = user
    @organization = organization
    @inviter      = inviter
    @token        = reset_token

    mail(
      to: @user.email,
      subject: "You're invited to join #{@organization.name} on Sales Gorilla"
    )
  end

  # Notice for someone who already has a Sales Gorilla account and was added to
  # a new organization — they can sign in and switch into it right away.
  def organization_added(user, organization, inviter)
    @user         = user
    @organization = organization
    @inviter      = inviter

    mail(
      to: @user.email,
      subject: "You've been added to #{@organization.name} on Sales Gorilla"
    )
  end

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
