# Pushes new WhatsApp US messages out over ActionCable so subscribed clients
# (web chat panel, mobile app) update without polling.
#
# Called from:
#   - TwilioWhatsappController#inbound      (inbound message persisted)
#   - WhatsappUsController#send_*           (outbound from web)
#   - Api::V2::WhatsappUsController#send_*  (outbound from mobile API)
#
# Best-effort: any exception is swallowed and logged. Broadcasts should never
# block a write path.
class WhatsappUsBroadcaster
  def self.broadcast(message)
    new(message).broadcast
  end

  def initialize(message)
    @message  = message
    @customer = message.customer
  end

  def broadcast
    return unless @message && @customer

    payload = {
      type:        'whatsapp_us.message',
      direction:   @message.direction,
      customer_id: @customer.id,
      message:     serialize
    }

    ActionCable.server.broadcast(WhatsappUsChannel.customer_stream(@customer.id), payload)
    ActionCable.server.broadcast(WhatsappUsChannel.user_stream(@customer.user_id), payload) if @customer.user_id
  rescue StandardError => e
    Rails.logger.warn("[WhatsappUsBroadcaster] broadcast failed: #{e.class} #{e.message}")
  end

  private

  def serialize
    attached = @message.media.attached? ? @message.media : nil
    {
      id:                 @message.id,
      message_id:         @message.message_id,
      body:               @message.body,
      direction:          @message.direction,
      status:             @message.status,
      timestamp:          (@message.timestamp || @message.created_at).iso8601,
      # Relative blob path — clients prefix with their configured API host.
      media_url:          attached ? Rails.application.routes.url_helpers.rails_blob_path(attached, only_path: true) : nil,
      media_filename:     attached&.filename.to_s.presence,
      media_content_type: attached&.content_type,
      template_sid:       @message.metadata&.dig('template_sid'),
      template_name:      @message.metadata&.dig('template_name')
    }
  end
end
