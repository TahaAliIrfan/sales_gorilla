# Receives Twilio WhatsApp webhooks (incoming messages + delivery status callbacks)
# and persists them into the whatsapp_messages table.
#
# This is a standalone, parallel path to the existing green-api WhatsApp
# integration (WhatsappMessageService / Whatsapp::ApiService) and does not
# touch it.
#
# Configure in the Twilio Console for the WhatsApp sender (whatsapp:+13022067878):
#   "When a message comes in"  -> POST https://crm.tecaudex.com/twilio/whatsapp/inbound
#   "Status callback URL"      -> POST https://crm.tecaudex.com/twilio/whatsapp/status
class TwilioWhatsappController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :inbound, :status ]
  before_action :verify_twilio_signature, only: [ :inbound, :status ]

  # Incoming WhatsApp message from a customer.
  def inbound
    from_phone = phone_from_whatsapp(params[:From])
    customer   = find_customer_by_phone(from_phone)

    if customer.nil?
      # whatsapp_messages.customer_id is NOT NULL, so we can't persist an
      # inbound message from a number that isn't a known customer. Log it so
      # it isn't silently lost.
      Rails.logger.warn("[TwilioWhatsapp] inbound from unknown number #{from_phone.inspect} " \
                        "(MessageSid=#{params[:MessageSid]}): #{params[:Body].to_s.truncate(120)}")
      return head :ok
    end

    message = customer.whatsapp_messages.find_or_initialize_by(message_id: params[:MessageSid])
    message.assign_attributes(
      remote_id: params[:WaId].presence || from_phone,
      body:      params[:Body].presence || media_summary,
      direction: "inbound",
      status:    "received",
      timestamp: Time.current,
      metadata:  inbound_metadata
    )
    message.save!

    # Download any attached media out-of-band (Twilio media URLs need auth).
    TwilioWhatsappMediaWorker.perform_async(message.id) if params[:NumMedia].to_i.positive?

    # Push a Firebase notification to the customer's assigned user.
    WhatsappInboundPushWorker.perform_async(message.id)

    # Live-push the message to subscribed ActionCable clients.
    WhatsappUsBroadcaster.broadcast(message)

    Rails.logger.info("[TwilioWhatsapp] stored inbound message #{params[:MessageSid]} for customer #{customer.id}")
    head :ok
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    # Twilio retries on non-2xx, which can race a duplicate insert. Treat an
    # already-stored message as success so Twilio stops retrying.
    Rails.logger.warn("[TwilioWhatsapp] inbound persist skipped (#{e.class}): #{e.message}")
    head :ok
  end

  # Delivery status callback for an outbound message (queued/sent/delivered/read/failed).
  def status
    message = WhatsappMessage.find_by(message_id: params[:MessageSid])
    if message
      message.update(status: params[:MessageStatus], metadata: (message.metadata || {}).merge(status_metadata))
      # Push the new tick (delivered/read/failed) to subscribed clients so the
      # message bubble updates without a poll. Clients upsert by id.
      WhatsappUsBroadcaster.broadcast(message)
      Rails.logger.info("[TwilioWhatsapp] status #{params[:MessageStatus]} for #{params[:MessageSid]}")
    end
    head :ok
  end

  private

  def inbound_metadata
    {
      provider:     "twilio",
      from:         params[:From],
      to:           params[:To],
      profile_name: params[:ProfileName],
      wa_id:        params[:WaId],
      num_media:    params[:NumMedia].to_i,
      media:        media_urls
    }.compact
  end

  def status_metadata
    {
      last_status:        params[:MessageStatus],
      error_code:         params[:ErrorCode],
      status_updated_at:  Time.current.iso8601
    }.compact
  end

  def media_urls
    count = params[:NumMedia].to_i
    return [] if count.zero?

    (0...count).map do |i|
      { url: params["MediaUrl#{i}"], content_type: params["MediaContentType#{i}"] }
    end
  end

  def media_summary
    count = params[:NumMedia].to_i
    count.positive? ? "[#{count} media attachment(s)]" : nil
  end

  # "whatsapp:+923004363534" -> "+923004363534"
  def phone_from_whatsapp(value)
    return nil if value.blank?

    value.to_s.sub(/\Awhatsapp:/, "").strip
  end

  def find_customer_by_phone(phone)
    return nil if phone.blank?

    Customer.find_by(phone: phone) ||
      Customer.where("phone LIKE ?", "%#{phone.gsub(/\D/, '').last(10)}").first
  end

  # Reject forged requests. Twilio signs each webhook with the account auth
  # token; only enforced in production so local/test posting stays easy.
  def verify_twilio_signature
    return true unless Rails.env.production?

    auth_token = Rails.application.credentials.dig(:TWILIO_AUTH_TOKEN)
    validator  = Twilio::Security::RequestValidator.new(auth_token)
    signature  = request.headers["X-Twilio-Signature"]

    unless validator.validate(request.original_url, request.request_parameters, signature)
      Rails.logger.error("[TwilioWhatsapp] invalid Twilio signature for #{request.original_url}")
      head :forbidden
    end
  end
end
