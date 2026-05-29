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

    file = params[:file]
    body = params[:body].to_s.strip
    return render_error('Customer has no phone number') if @customer.phone.blank?
    return render_error('Message cannot be blank') if body.blank? && file.blank?

    unless @customer.whatsapp_us_window_open?
      return render_error('The 24-hour reply window has closed. The customer must message first before you can send a freeform message.', :forbidden)
    end

    file.present? ? send_media_message(file, body) : send_text_message(body)
  end

  # GET /customers/:customer_id/whatsapp_us/templates.json
  def templates
    authorize @customer, :show?

    render json: {
      templates: WhatsappTemplate.approved.ordered.map { |t| serialize_template(t) }
    }
  end

  # POST /customers/:customer_id/whatsapp_us/templates/sync
  # Admin-only: pulls latest approved templates from Twilio.
  def sync_templates
    authorize @customer, :show?
    return render_error('Admins only', :forbidden) unless current_user&.admin?

    result = TwilioWhatsappTemplatesService.new.sync!
    return render_error(result[:error] || 'Sync failed', :unprocessable_entity) unless result[:success]

    render json: {
      success: true,
      synced: result[:synced],
      skipped: result[:skipped],
      templates: WhatsappTemplate.approved.ordered.map { |t| serialize_template(t) }
    }
  end

  # POST /customers/:customer_id/whatsapp_us/send_template
  def send_template
    authorize @customer, :show?
    return render_error('Customer has no phone number') if @customer.phone.blank?

    template = WhatsappTemplate.approved.find_by(content_sid: params[:content_sid])
    return render_error('Template not found or not approved', :not_found) unless template

    variables = sanitize_variables(template, params[:variables])

    # Media templates need a file. Upload it to ActiveStorage, get a signed URL,
    # and slot that URL into every variable position that lives inside the
    # template's media field.
    file = params[:file]
    media_blob = nil
    if template.has_media?
      return render_error('This template requires a file attachment') if file.blank?

      validation = validate_media(file)
      return render_error(validation[:error]) unless validation[:valid]

      media_blob = ActiveStorage::Blob.create_and_upload!(
        io: file.tempfile,
        filename: file.original_filename,
        content_type: file.content_type
      )
      signed_url = media_blob.url(expires_in: 1.hour)
      template.media_variable_keys.each { |k| variables[k] = signed_url }
    end

    result = TwilioWhatsappService.new.send_template(
      to_phone:          @customer.phone,
      content_sid:       template.content_sid,
      content_variables: variables
    )
    unless result[:success]
      media_blob&.purge_later
      return render_error(result[:error] || 'Failed to send template', :unprocessable_entity)
    end

    message = persist_outbound(
      sid:    result[:sid],
      status: result[:status],
      body:   template.render_body(variables.except(*template.media_variable_keys))
    )
    message.media.attach(media_blob) if media_blob
    # Stash a marker so the chat UI can render a "template" badge later if we want.
    message.update(metadata: (message.metadata || {}).merge(
      template_sid:  template.content_sid,
      template_name: template.friendly_name
    ))

    UserKpiRecord.track!(current_user&.id, :whatsapp_messages_sent)
    render json: { success: true, message: serialize(message) }
  end

  private

  # Keep only the variable keys the template actually declares, and coerce
  # whatever the client sent into strings.
  def sanitize_variables(template, raw)
    return {} if raw.blank?
    raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    template.variable_keys.each_with_object({}) do |k, h|
      val = raw[k] || raw[k.to_sym] || raw[k.to_i]
      h[k] = val.to_s if val.present?
    end
  end

  def serialize_template(t)
    {
      content_sid:        t.content_sid,
      friendly_name:      t.friendly_name,
      language:           t.language,
      category:           t.category,
      body:               t.body,
      variable_keys:      t.variable_keys,
      text_variable_keys: t.text_variable_keys,
      has_media:          t.has_media?,
      last_synced_at:     t.last_synced_at&.iso8601
    }
  end


  # Text-only outbound message.
  def send_text_message(body)
    result = TwilioWhatsappService.new.send_text(to_phone: @customer.phone, body: body)
    return render_error(result[:error] || 'Failed to send message', :unprocessable_entity) unless result[:success]

    message = persist_outbound(sid: result[:sid], status: result[:status], body: body)
    UserKpiRecord.track!(current_user&.id, :whatsapp_messages_sent)
    render json: { success: true, message: serialize(message) }
  end

  # Outbound message with an uploaded document/image. The file is stored first
  # so Twilio can fetch it from a signed URL, then the message is persisted with
  # the same blob attached.
  def send_media_message(file, caption)
    validation = validate_media(file)
    return render_error(validation[:error]) unless validation[:valid]

    blob = ActiveStorage::Blob.create_and_upload!(
      io: file.tempfile,
      filename: file.original_filename,
      content_type: file.content_type
    )

    result = TwilioWhatsappService.new.send_media(
      to_phone: @customer.phone,
      media_url: blob.url(expires_in: 1.hour),
      body: caption.presence
    )

    unless result[:success]
      blob.purge_later
      return render_error(result[:error] || 'Failed to send file', :unprocessable_entity)
    end

    message = persist_outbound(
      sid: result[:sid],
      status: result[:status],
      body: caption.presence || file.original_filename
    )
    message.media.attach(blob)

    UserKpiRecord.track!(current_user&.id, :whatsapp_messages_sent)
    render json: { success: true, message: serialize(message) }
  end

  def persist_outbound(sid:, status:, body:)
    @customer.whatsapp_messages.create!(
      message_id: sid,
      remote_id:  @customer.phone,
      body:       body,
      direction:  'outbound',
      status:     status || 'queued',
      timestamp:  Time.current,
      metadata:   { provider: 'twilio', to: "whatsapp:#{@customer.phone}", from: TwilioWhatsappService::FROM, sent_by_user_id: current_user&.id }
    )
  end

  ALLOWED_MEDIA_TYPES = %w[
    image/jpeg image/jpg image/png image/gif image/webp
    video/mp4 video/3gp video/webm
    audio/mpeg audio/mp3 audio/ogg audio/wav audio/m4a audio/flac
    application/pdf application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    text/plain text/csv application/json application/xml application/zip
  ].freeze

  # WhatsApp caps media at 16MB; we mirror that.
  MAX_MEDIA_BYTES = 16.megabytes

  def validate_media(file)
    return { valid: false, error: 'No file provided' } unless file.respond_to?(:content_type)
    unless ALLOWED_MEDIA_TYPES.include?(file.content_type)
      return { valid: false, error: "File type '#{file.content_type}' is not supported" }
    end
    if file.size > MAX_MEDIA_BYTES
      return { valid: false, error: "File is too large (max #{MAX_MEDIA_BYTES / 1.megabyte}MB)" }
    end

    { valid: true }
  end

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def serialize(message)
    attached = message.media.attached? ? message.media : nil
    {
      id: message.id,
      message_id: message.message_id,
      body: message.body,
      direction: message.direction,
      status: message.status,
      timestamp: (message.timestamp || message.created_at).iso8601,
      formatted_time: (message.timestamp || message.created_at).strftime('%b %d, %H:%M'),
      media_url: attached ? rails_blob_path(attached, only_path: true) : nil,
      media_filename: attached&.filename.to_s.presence,
      media_content_type: attached&.content_type,
      media: message.metadata&.dig('media') || []
    }
  end

  def render_error(message, status = :unprocessable_entity)
    render json: { success: false, error: message }, status: status
  end
end
