# Pushes a Firebase notification when a Twilio WhatsApp inbound message
# arrives. Fans out to:
#   - the customer's assigned user (the rep working the lead)
#   - every active admin (so leadership sees every inbound message)
# Best-effort: missing FCM token or unconfigured Firebase = silent no-op for
# that recipient; other recipients still get the push.
class WhatsappInboundPushWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3, queue: 'notifications'

  def perform(message_id)
    message  = WhatsappMessage.find_by(id: message_id)
    return unless message && message.direction == 'inbound'

    customer = message.customer
    return unless customer

    title = 'New WhatsApp message'
    body  = "#{customer.name.presence || 'Customer'} has sent you a message"
    data  = {
      type:        'whatsapp_us_message',
      customer_id: customer.id,
      message_id:  message.id
    }

    svc = FirebasePushService.new
    recipients(customer).each do |user|
      next if user.fcm_token.blank?

      result = svc.send_to_token(token: user.fcm_token, title: title, body: body, data: data)
      if result[:success]
        Rails.logger.info("[FCM] inbound push delivered to user #{user.id} for customer #{customer.id}")
      else
        Rails.logger.warn("[FCM] inbound push skipped for user #{user.id}: #{result[:error]}")
      end
    end
  end

  private

  # Assignee + all active admins, deduplicated. The assignee comes first so the
  # rep on point is notified before fan-out latency.
  def recipients(customer)
    list = []
    list << customer.user if customer.user&.active?
    list.concat(User.active_users.joins(:roles).where(roles: { key: 'admin' }).distinct.to_a)
    list.uniq
  end
end
