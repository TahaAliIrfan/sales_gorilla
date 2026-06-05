# Receives Twilio WhatsApp webhooks (incoming messages + delivery status callbacks)
# and persists them into the whatsapp_messages table.
#
# Multi-tenant by sender number: the `To` field on the inbound payload is the
# org's configured WhatsApp sender. We look it up against connected_pages-style
# settings on each org's `whatsapp` feature and switch ActsAsTenant accordingly
# before persisting. Status callbacks are routed by `MessageSid` → existing
# WhatsappMessage (which already carries its org via acts_as_tenant).
class TwilioWhatsappController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :inbound, :status ]
  before_action :find_org_for_inbound, only: :inbound
  before_action :verify_twilio_signature, only: [ :inbound, :status ]

  def inbound
    ActsAsTenant.with_tenant(@org) do
      from_phone = phone_from_whatsapp(params[:From])
      customer   = find_customer_by_phone(from_phone)

      if customer.nil?
        Rails.logger.warn("[TwilioWhatsapp] inbound from unknown number #{from_phone.inspect} " \
                          "in org=#{@org.subdomain} (MessageSid=#{params[:MessageSid]}): " \
                          "#{params[:Body].to_s.truncate(120)}")
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

      TwilioWhatsappMediaWorker.perform_async(message.id) if params[:NumMedia].to_i.positive?
      WhatsappInboundPushWorker.perform_async(message.id)
      WhatsappUsBroadcaster.broadcast(message)

      Rails.logger.info("[TwilioWhatsapp] stored inbound message #{params[:MessageSid]} for customer #{customer.id}")
      head :ok
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[TwilioWhatsapp] inbound persist skipped (#{e.class}): #{e.message}")
    head :ok
  end

  # Delivery status callback for an outbound message. The message itself
  # carries its org via acts_as_tenant, so we don't need to route by `To`.
  def status
    ActsAsTenant.without_tenant do
      message = WhatsappMessage.find_by(message_id: params[:MessageSid])
      if message
        message.update(status: params[:MessageStatus], metadata: (message.metadata || {}).merge(status_metadata))
        WhatsappUsBroadcaster.broadcast(message)
        Rails.logger.info("[TwilioWhatsapp] status #{params[:MessageStatus]} for #{params[:MessageSid]}")
      end
    end
    head :ok
  end

  private

  # Match the `To` field (the org's sender number) to whichever org has it
  # configured in their `whatsapp` feature settings. If none, drop the message
  # (return 200 so Twilio stops retrying, and log it).
  def find_org_for_inbound
    to_phone = phone_from_whatsapp(params[:To])
    return head(:ok) if to_phone.blank?

    @org = lookup_org_by_sender(to_phone)
    unless @org
      Rails.logger.warn("[TwilioWhatsapp] inbound to unknown sender #{to_phone.inspect} — no org has this number configured")
      head :ok
    end
  end

  def lookup_org_by_sender(to_phone)
    normalized = to_phone.to_s.strip
    ActsAsTenant.without_tenant do
      OrganizationFeature.where(key: "whatsapp", enabled: true).find_each do |f|
        sender = f.settings_hash["sender_number"].to_s.strip
        return f.organization if sender == normalized
      end
    end
    nil
  end

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

  def phone_from_whatsapp(value)
    return nil if value.blank?
    value.to_s.sub(/\Awhatsapp:/, "").strip
  end

  def find_customer_by_phone(phone)
    return nil if phone.blank?

    Customer.find_by(phone: phone) ||
      Customer.where("phone LIKE ?", "%#{phone.gsub(/\D/, '').last(10)}").first
  end

  # Reject forged requests. Twilio signs each webhook with the org's auth
  # token; verify against the org we routed to (status uses any org's token
  # since signatures aren't org-specific in a way we can easily check there).
  def verify_twilio_signature
    return true unless Rails.env.production?

    auth_token = @org&.feature(:whatsapp)&.settings_hash&.dig("auth_token") ||
                 Rails.application.credentials.dig(:TWILIO_AUTH_TOKEN) # status-only fallback
    return head(:forbidden) if auth_token.blank?

    validator = Twilio::Security::RequestValidator.new(auth_token)
    signature = request.headers["X-Twilio-Signature"]

    unless validator.validate(request.original_url, request.request_parameters, signature)
      Rails.logger.error("[TwilioWhatsapp] invalid Twilio signature for #{request.original_url}")
      head :forbidden
    end
  end
end
