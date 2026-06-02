# Pushes a Firebase notification to the customer's assigned user (and the
# admins/manager chain, if you ever want to fan it out further — keep it to the
# assignee for now to avoid noise) when a Twilio WhatsApp inbound message
# arrives. Best-effort: missing FCM token or unconfigured Firebase = no-op.
class WhatsappInboundPushWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3, queue: 'notifications'

  def perform(message_id)
    message  = WhatsappMessage.find_by(id: message_id)
    return unless message && message.direction == 'inbound'

    customer = message.customer
    user     = customer&.user
    return unless user&.fcm_token.present?

    title = 'New WhatsApp message'
    body  = "#{customer.name.presence || 'Customer'} has sent you a message"

    result = FirebasePushService.new.send_to_token(
      token: user.fcm_token,
      title: title,
      body:  body,
      data: {
        type:        'whatsapp_us_message',
        customer_id: customer.id,
        message_id:  message.id
      }
    )

    if result[:success]
      Rails.logger.info("[FCM] inbound push delivered to user #{user.id} for customer #{customer.id}")
    else
      Rails.logger.warn("[FCM] inbound push skipped: #{result[:error]}")
    end
  end
end
