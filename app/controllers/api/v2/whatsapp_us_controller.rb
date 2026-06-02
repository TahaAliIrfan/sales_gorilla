# Mobile API for the Twilio WhatsApp ("WhatsApp US") channel. Parallel to
# Api::V2::WhatsappController (which is the green-api side) and shares the
# whatsapp_messages table.
#
# Endpoints:
#   GET    /api/v2/whatsapp_us/conversations              — customers grouped, last message preview
#   GET    /api/v2/whatsapp_us/customers/:id/messages     — full thread
#   POST   /api/v2/whatsapp_us/customers/:id/send         — text or media (multipart)
#   POST   /api/v2/whatsapp_us/customers/:id/send_template — approved template
#   GET    /api/v2/whatsapp_us/templates                  — list approved templates
#   POST   /api/v2/whatsapp_us/templates/sync             — admin-only: pull from Twilio
class Api::V2::WhatsappUsController < Api::V2::BaseController
  before_action :set_customer, only: [:messages, :send_message, :send_template]

  # GET /api/v2/whatsapp_us/conversations
  # Customers the caller can see who have at least one WhatsApp message,
  # ordered by most recent activity. Returns the latest message and the
  # 24h-window state so the mobile composer can mirror the web UI.
  def conversations
    customers = accessible_customers
                  .joins(:whatsapp_messages)
                  .select('customers.*, MAX(whatsapp_messages.timestamp) AS last_message_at')
                  .group('customers.id')
                  .order('MAX(whatsapp_messages.timestamp) DESC')
                  .limit(params[:limit]&.to_i || 100)

    payload = customers.map { |c| conversation_summary(c) }
    render_success(payload, 'Conversations retrieved')
  end

  # GET /api/v2/whatsapp_us/customers/:id/messages
  def messages
    msgs = @customer.whatsapp_messages
                    .order(:timestamp, :created_at)
                    .limit(params[:limit]&.to_i || 200)

    render_success({
      customer: customer_brief(@customer),
      window_open: @customer.whatsapp_us_window_open?,
      last_inbound_at: @customer.whatsapp_us_last_inbound_at&.iso8601,
      messages: msgs.map { |m| serialize_message(m) }
    }, 'Messages retrieved')
  end

  # POST /api/v2/whatsapp_us/customers/:id/send
  # Body: { body: "...", file: <multipart upload> }  (either or both)
  def send_message
    body = params[:body].to_s.strip
    file = params[:file]
    return render_error('Customer has no phone number', nil, :unprocessable_entity) if @customer.phone.blank?
    return render_error('Message cannot be blank', nil, :unprocessable_entity) if body.blank? && file.blank?

    unless @customer.whatsapp_us_window_open?
      return render_error(
        'The 24-hour reply window has closed. The customer must message first, or use an approved template.',
        nil, :forbidden
      )
    end

    file.present? ? send_media_via_twilio(file, body) : send_text_via_twilio(body)
  end

  # POST /api/v2/whatsapp_us/customers/:id/send_template
  # Body: { content_sid: "HX...", variables: { "customer_name" => "Taha", ... } }
  def send_template
    template = WhatsappTemplate.approved.find_by(content_sid: params[:content_sid])
    return render_error('Template not found or not approved', nil, :not_found) unless template
    return render_error('Customer has no phone number', nil, :unprocessable_entity) if @customer.phone.blank?

    variables = sanitize_variables(template, params[:variables])

    result = TwilioWhatsappService.new.send_template(
      to_phone:          @customer.phone,
      content_sid:       template.content_sid,
      content_variables: variables
    )
    return render_error(result[:error] || 'Failed to send template', nil, :unprocessable_entity) unless result[:success]

    message = persist_outbound(
      sid:    result[:sid],
      status: result[:status],
      body:   template.render_body(variables),
      extra:  { template_sid: template.content_sid, template_name: template.friendly_name }
    )

    UserKpiRecord.track!(current_user&.id, :whatsapp_messages_sent)
    render_success({ message: serialize_message(message) }, 'Template sent')
  end

  # GET /api/v2/whatsapp_us/templates
  def templates
    list = WhatsappTemplate.approved.ordered.map { |t| serialize_template(t) }
    render_success({ templates: list }, 'Templates retrieved')
  end

  # POST /api/v2/whatsapp_us/templates/sync — admin only
  def sync_templates
    return render_error('Admins only', nil, :forbidden) unless current_user_admin?

    result = TwilioWhatsappTemplatesService.new.sync!
    return render_error(result[:error] || 'Sync failed', nil, :unprocessable_entity) unless result[:success]

    render_success(
      {
        synced: result[:synced],
        skipped: result[:skipped],
        templates: WhatsappTemplate.approved.ordered.map { |t| serialize_template(t) }
      },
      'Templates synced'
    )
  end

  private

  # ---- helpers ------------------------------------------------------------

  def set_customer
    @customer = accessible_customers.find(params[:customer_id] || params[:id])
  end

  # Role-based scope mirroring Api::V2::WhatsappController#accessible_customers
  # so mobile callers see the same set as web users.
  def accessible_customers
    return Customer.none unless current_user

    case current_user.highest_role&.key
    when 'admin'
      Customer.all
    when 'manager'
      user_ids = [current_user.id] + current_user.associates.pluck(:id)
      Customer.where(user_id: user_ids)
    else
      current_user.customers
    end
  rescue StandardError => e
    Rails.logger.error("[WhatsappUs] accessible_customers fallback: #{e.message}")
    current_user&.customers || Customer.none
  end

  # ---- send helpers (mirror WhatsappUsController web flow) ----------------

  def send_text_via_twilio(body)
    result = TwilioWhatsappService.new.send_text(to_phone: @customer.phone, body: body)
    return render_error(result[:error] || 'Failed to send message', nil, :unprocessable_entity) unless result[:success]

    message = persist_outbound(sid: result[:sid], status: result[:status], body: body)
    UserKpiRecord.track!(current_user&.id, :whatsapp_messages_sent)
    render_success({ message: serialize_message(message) }, 'Message sent')
  end

  def send_media_via_twilio(file, caption)
    validation = validate_media(file)
    return render_error(validation[:error], nil, :unprocessable_entity) unless validation[:valid]

    blob = ActiveStorage::Blob.create_and_upload!(
      io: file.tempfile,
      filename: file.original_filename,
      content_type: file.content_type
    )

    result = TwilioWhatsappService.new.send_media(
      to_phone:  @customer.phone,
      media_url: blob.url(expires_in: 1.hour),
      body:      caption.presence
    )

    unless result[:success]
      blob.purge_later
      return render_error(result[:error] || 'Failed to send file', nil, :unprocessable_entity)
    end

    message = persist_outbound(
      sid: result[:sid],
      status: result[:status],
      body: caption.presence || file.original_filename
    )
    message.media.attach(blob)

    UserKpiRecord.track!(current_user&.id, :whatsapp_messages_sent)
    render_success({ message: serialize_message(message) }, 'Message sent')
  end

  def persist_outbound(sid:, status:, body:, extra: {})
    metadata = {
      provider: 'twilio',
      to:       "whatsapp:#{@customer.phone}",
      from:     TwilioWhatsappService::FROM,
      sent_by_user_id: current_user&.id
    }.merge(extra)

    @customer.whatsapp_messages.create!(
      message_id: sid,
      remote_id:  @customer.phone,
      body:       body,
      direction:  'outbound',
      status:     status || 'queued',
      timestamp:  Time.current,
      metadata:   metadata
    )
  end

  def sanitize_variables(template, raw)
    return {} if raw.blank?
    raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    template.variable_keys.each_with_object({}) do |k, h|
      val = raw[k] || raw[k.to_sym] || raw[k.to_i]
      h[k] = val.to_s if val.present?
    end
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

  # ---- serializers --------------------------------------------------------

  def conversation_summary(customer)
    last = customer.whatsapp_messages.order(timestamp: :desc, created_at: :desc).first
    {
      customer:        customer_brief(customer),
      last_message:    last && serialize_message(last),
      last_message_at: (last&.timestamp || last&.created_at)&.iso8601,
      window_open:     customer.whatsapp_us_window_open?,
      unread:          customer.whatsapp_messages.where(direction: 'inbound').where(status: 'received').count
    }
  end

  def customer_brief(customer)
    {
      id:        customer.id,
      name:      customer.name,
      phone:     customer.phone,
      whatsapp_status: customer.whatsapp_status,
      assigned_user_id: customer.user_id
    }
  end

  def serialize_message(message)
    attached = message.media.attached? ? message.media : nil
    {
      id:               message.id,
      message_id:       message.message_id,
      body:             message.body,
      direction:        message.direction,
      status:           message.status,
      timestamp:        (message.timestamp || message.created_at).iso8601,
      media_url:        attached ? Rails.application.routes.url_helpers.rails_blob_url(attached, only_path: false, host: host_for_blob) : nil,
      media_filename:   attached&.filename.to_s.presence,
      media_content_type: attached&.content_type,
      template_sid:     message.metadata&.dig('template_sid'),
      template_name:    message.metadata&.dig('template_name')
    }
  end

  def serialize_template(t)
    {
      content_sid:    t.content_sid,
      friendly_name:  t.friendly_name,
      language:       t.language,
      category:       t.category,
      body:           t.body,
      variable_keys:  t.variable_keys,
      last_synced_at: t.last_synced_at&.iso8601
    }
  end

  # Mobile clients need fully-qualified blob URLs.
  def host_for_blob
    request.host_with_port
  end
end
