# Dashboard UI for the Twilio-backed "WhatsApp US" channel on the customer
# show page. Reads/writes the whatsapp_messages table. Inbound messages arrive
# via TwilioWhatsappController (webhook); this controller lists them and sends
# outbound replies through TwilioWhatsappService.
class WhatsappUsController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_customer
  after_action :verify_authorized

  # GET /customers/:customer_id/whatsapp_us.json
  def index
    authorize @customer, :show?

    render json: {
      messages: @customer.whatsapp_messages.order(:timestamp, :created_at).map { |m| serialize(m) },
      window_open: @customer.whatsapp_us_window_open?,
      last_inbound_at: @customer.whatsapp_us_last_inbound_at&.iso8601
    }
  end

  # POST /customers/:customer_id/whatsapp_us
  def create
    authorize @customer, :show?

    body = params[:body].to_s.strip
    return render_error('Message cannot be blank') if body.blank?
    return render_error('Customer has no phone number') if @customer.phone.blank?

    unless @customer.whatsapp_us_window_open?
      return render_error('The 24-hour reply window has closed. The customer must message first before you can send a freeform message.', :forbidden)
    end

    result = TwilioWhatsappService.new.send_text(to_phone: @customer.phone, body: body)

    unless result[:success]
      return render_error(result[:error] || 'Failed to send message', :unprocessable_entity)
    end

    message = @customer.whatsapp_messages.create!(
      message_id: result[:sid],
      remote_id:  @customer.phone,
      body:       body,
      direction:  'outbound',
      status:     result[:status] || 'queued',
      timestamp:  Time.current,
      metadata:   { provider: 'twilio', to: "whatsapp:#{@customer.phone}", from: TwilioWhatsappService::FROM, sent_by_user_id: current_user&.id }
    )

    UserKpiRecord.track!(current_user&.id, :whatsapp_messages_sent)

    render json: { success: true, message: serialize(message) }
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def serialize(message)
    {
      id: message.id,
      message_id: message.message_id,
      body: message.body,
      direction: message.direction,
      status: message.status,
      timestamp: (message.timestamp || message.created_at).iso8601,
      formatted_time: (message.timestamp || message.created_at).strftime('%b %d, %H:%M'),
      media: message.metadata&.dig('media') || []
    }
  end

  def render_error(message, status = :unprocessable_entity)
    render json: { success: false, error: message }, status: status
  end
end
