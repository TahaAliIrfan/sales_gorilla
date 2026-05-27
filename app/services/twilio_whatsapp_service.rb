# Sends outbound WhatsApp messages through Twilio.
#
# Standalone, parallel to the green-api path (WhatsappMessageService). Persists
# nothing itself — the caller stores the message in whatsapp_messages so that
# the returned Twilio SID can be saved as message_id (and later updated by the
# /twilio/whatsapp/status callback).
#
# WhatsApp rules enforced by Twilio:
#   - A freeform `body` message only delivers within 24h of the customer's last
#     inbound message; otherwise Twilio returns error 63016.
#   - Outside that window an approved Content template (content_sid) is required.
class TwilioWhatsappService
  # Twilio WhatsApp sender (hardcoded for now).
  FROM = 'whatsapp:+13022067878'.freeze

  def initialize
    account_sid = Rails.application.credentials.dig(:TWILIO_ACCOUNT_SID)
    auth_token  = Rails.application.credentials.dig(:TWILIO_AUTH_TOKEN)

    raise 'Twilio credentials not configured' unless account_sid && auth_token

    @client      = Twilio::REST::Client.new(account_sid, auth_token)
    @status_callback = "#{app_url}/twilio/whatsapp/status"
  end

  # Send a freeform text message. Returns a result hash; on success includes the
  # Twilio message SID and status.
  def send_text(to_phone:, body:)
    return { success: false, error: 'Phone number is missing' } if to_phone.blank?
    return { success: false, error: 'Message cannot be blank' }  if body.blank?

    message = @client.messages.create(
      from: FROM,
      to:   to_whatsapp(to_phone),
      body: body,
      status_callback: @status_callback
    )

    { success: true, sid: message.sid, status: message.status }
  rescue Twilio::REST::RestError => e
    Rails.logger.error("[TwilioWhatsapp] send_text failed (#{e.code}): #{e.message}")
    { success: false, error: twilio_error_message(e), code: e.code }
  rescue StandardError => e
    Rails.logger.error("[TwilioWhatsapp] send_text error: #{e.message}")
    { success: false, error: e.message }
  end

  # Send a media message (document/image/etc). `media_url` must be a publicly
  # fetchable URL — Twilio downloads the file from it. `body` is an optional
  # caption. Same 24h-window rules apply as send_text.
  def send_media(to_phone:, media_url:, body: nil)
    return { success: false, error: 'Phone number is missing' } if to_phone.blank?
    return { success: false, error: 'Media URL is missing' }    if media_url.blank?

    params = {
      from: FROM,
      to:   to_whatsapp(to_phone),
      media_url: [media_url],
      status_callback: @status_callback
    }
    params[:body] = body if body.present?

    message = @client.messages.create(**params)

    { success: true, sid: message.sid, status: message.status }
  rescue Twilio::REST::RestError => e
    Rails.logger.error("[TwilioWhatsapp] send_media failed (#{e.code}): #{e.message}")
    { success: false, error: twilio_error_message(e), code: e.code }
  rescue StandardError => e
    Rails.logger.error("[TwilioWhatsapp] send_media error: #{e.message}")
    { success: false, error: e.message }
  end

  private

  def to_whatsapp(phone)
    phone.to_s.start_with?('whatsapp:') ? phone : "whatsapp:#{phone}"
  end

  def twilio_error_message(error)
    # 63016: freeform message sent outside the 24-hour customer service window.
    if error.code == 63016
      'The 24-hour reply window has closed. The customer must message first, or use an approved template.'
    else
      error.message
    end
  end

  def app_url
    'https://crm.tecaudex.com'
  end
end
