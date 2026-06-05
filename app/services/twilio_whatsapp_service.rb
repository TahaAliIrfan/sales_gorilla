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
  class NotConfigured < StandardError; end

  # Caller may pass `organization:` explicitly (workers should), otherwise we
  # fall back to ActsAsTenant.current_tenant. Credentials + sender number are
  # read from the org's `whatsapp` feature (Settings > Features).
  def initialize(organization: nil)
    @organization = organization || ActsAsTenant.current_tenant ||
                    raise(ArgumentError, "TwilioWhatsappService needs an organization (ActsAsTenant.current_tenant or `organization:` arg)")

    feature = @organization.feature(:whatsapp)
    raise NotConfigured, "WhatsApp not enabled for #{@organization.subdomain}" unless feature&.enabled?

    settings = feature.settings_hash
    @account_sid   = settings["account_sid"].presence ||
                     raise(NotConfigured, "WhatsApp: account_sid missing for #{@organization.subdomain}")
    @auth_token    = settings["auth_token"].presence ||
                     raise(NotConfigured, "WhatsApp: auth_token missing for #{@organization.subdomain}")
    @sender_number = settings["sender_number"].presence ||
                     raise(NotConfigured, "WhatsApp: sender_number missing for #{@organization.subdomain}")

    @from = to_whatsapp(@sender_number)
    @app_url = settings["app_url"].presence || "https://crm.tecaudex.com"
    @client = Twilio::REST::Client.new(@account_sid, @auth_token)
    @status_callback = "#{@app_url}/twilio/whatsapp/status"
  end

  # Public accessor for the configured sender (used by the webhook router and
  # the Settings UI to display the value).
  attr_reader :sender_number

  # Convenience for callers that only need the `whatsapp:+NNN` string (e.g.
  # to store on a WhatsappMessage's metadata) without instantiating the
  # service. Returns nil if the org hasn't configured a sender.
  def self.from_for(organization)
    sender = organization&.feature(:whatsapp)&.settings_hash&.dig("sender_number")
    sender.present? ? "whatsapp:#{sender}" : nil
  end

  # Send a freeform text message. Returns a result hash; on success includes the
  # Twilio message SID and status.
  def send_text(to_phone:, body:)
    return { success: false, error: "Phone number is missing" } if to_phone.blank?
    return { success: false, error: "Message cannot be blank" }  if body.blank?

    message = @client.messages.create(
      from: @from,
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

  # Send an approved Content template. Works outside the 24h window — that's
  # the whole reason templates exist. `content_variables` is a hash keyed by
  # variable position ("1", "2", ...) that Twilio substitutes into the template.
  def send_template(to_phone:, content_sid:, content_variables: {})
    return { success: false, error: "Phone number is missing" } if to_phone.blank?
    return { success: false, error: "Template is missing" }    if content_sid.blank?

    params = {
      from: @from,
      to:   to_whatsapp(to_phone),
      content_sid: content_sid,
      status_callback: @status_callback
    }
    params[:content_variables] = content_variables.to_json if content_variables.present?

    message = @client.messages.create(**params)
    { success: true, sid: message.sid, status: message.status }
  rescue Twilio::REST::RestError => e
    Rails.logger.error("[TwilioWhatsapp] send_template failed (#{e.code}) sid=#{content_sid} vars=#{content_variables.inspect}: #{e.message}")
    { success: false, error: twilio_error_message(e), code: e.code }
  rescue StandardError => e
    Rails.logger.error("[TwilioWhatsapp] send_template error: #{e.message}")
    { success: false, error: e.message }
  end

  # Fetches every Twilio WhatsApp message exchanged between our `FROM` sender
  # and the given customer phone, in both directions. Used by the chat "Sync"
  # button to rebuild local state from Twilio's source-of-truth.
  def list_messages_for(phone:, limit: 200)
    return [] if phone.blank?

    to_addr = to_whatsapp(phone)
    outbound = @client.messages.list(from: @from, to: to_addr, limit: limit)
    inbound  = @client.messages.list(from: to_addr, to: @from, limit: limit)

    (outbound + inbound).sort_by { |m| (m.date_sent || m.date_created || Time.current).to_i }
  rescue Twilio::REST::RestError => e
    Rails.logger.error("[TwilioWhatsapp] list_messages_for failed (#{e.code}): #{e.message}")
    []
  end

  # Fetches the current status of a previously-sent message from Twilio.
  # Used to refresh stuck `queued` messages when the status webhook didn't
  # fire (e.g. dev/localhost) or got lost.
  def refresh_status(sid)
    msg = @client.messages(sid).fetch
    {
      success:       true,
      status:        msg.status,
      error_code:    msg.error_code,
      error_message: msg.error_message
    }
  rescue Twilio::REST::RestError => e
    Rails.logger.warn("[TwilioWhatsapp] refresh_status failed for #{sid} (#{e.code}): #{e.message}")
    { success: false, error: e.message, code: e.code }
  end

  # Send a media message (document/image/etc). `media_url` must be a publicly
  # fetchable URL — Twilio downloads the file from it. `body` is an optional
  # caption. Same 24h-window rules apply as send_text.
  def send_media(to_phone:, media_url:, body: nil)
    return { success: false, error: "Phone number is missing" } if to_phone.blank?
    return { success: false, error: "Media URL is missing" }    if media_url.blank?

    params = {
      from: @from,
      to:   to_whatsapp(to_phone),
      media_url: [ media_url ],
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
    phone.to_s.start_with?("whatsapp:") ? phone : "whatsapp:#{phone}"
  end

  def twilio_error_message(error)
    # 63016: freeform message sent outside the 24-hour customer service window.
    if error.code == 63016
      "The 24-hour reply window has closed. The customer must message first, or use an approved template."
    else
      error.message
    end
  end

end
