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
  before_action :set_customer, only: [:messages, :send_message, :send_template, :mark_read]

  # GET /api/v2/whatsapp_us/conversations
  # Customers the caller can see who have at least one WhatsApp message,
  # ordered by most recent activity. Returns the latest message and the
  # 24h-window state so the mobile composer can mirror the web UI.
  def conversations
    base = accessible_customers
             .joins(:whatsapp_messages)
             .select('customers.*, MAX(whatsapp_messages.timestamp) AS last_message_at')
             .group('customers.id')
             .order('MAX(whatsapp_messages.timestamp) DESC')

    total = accessible_customers.joins(:whatsapp_messages).distinct.count
    scoped, pagination = paginate(base, total)

    render_success(
      { conversations: scoped.map { |c| conversation_summary(c) }, pagination: pagination },
      'Conversations retrieved'
    )
  end

  # GET /api/v2/whatsapp_us/customers/:id/messages
  def messages
    base = @customer.whatsapp_messages.order(:timestamp, :created_at)
    base = base.where('id > ?', params[:after_id].to_i) if params[:after_id].present?
    total = base.count
    scoped, pagination = paginate(base, total)

    render_success({
      customer: customer_brief(@customer),
      window_open: @customer.whatsapp_us_window_open?,
      last_inbound_at: @customer.whatsapp_us_last_inbound_at&.iso8601,
      messages: scoped.map { |m| serialize_message(m) },
      pagination: pagination
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
  # JSON:      { content_sid: "HX...", variables: { "customer_name" => "Taha", ... } }
  # Multipart: same fields as form-data, plus `file` for templates whose media URL
  #            references a variable (e.g. Cost Calculator Report). The file is
  #            uploaded to Active Storage and its signed_id substituted into the
  #            template's media variable(s); Twilio fetches it via
  #            WhatsappMediaController (`https://crm.tecaudex.com/wa/media/{{1}}`).
  def send_template
    template = WhatsappTemplate.approved.find_by(content_sid: params[:content_sid])
    return render_error('Template not found or not approved', nil, :not_found) unless template
    return render_error('Customer has no phone number', nil, :unprocessable_entity) if @customer.phone.blank?

    variables  = sanitize_variables(template, params[:variables])
    file       = params[:file]
    media_blob = nil

    if template.requires_media_upload?
      return render_error('This template requires a file attachment', nil, :unprocessable_entity) if file.blank?

      validation = validate_media(file)
      return render_error(validation[:error], nil, :unprocessable_entity) unless validation[:valid]

      media_blob = ActiveStorage::Blob.create_and_upload!(
        io:           file.tempfile,
        filename:     file.original_filename,
        content_type: file.content_type
      )
      media_token = media_blob.signed_id(expires_in: 7.days)
      template.media_variable_keys.each { |k| variables[k] = media_token }
    end

    rendered_body = template.render_body(variables.except(*template.media_variable_keys))
    result = TwilioWhatsappService.new.send_template(
      to_phone:          @customer.phone,
      content_sid:       template.content_sid,
      content_variables: variables
    )

    unless result[:success]
      media_blob&.purge_later
      return render_error(result[:error] || 'Failed to send template', nil, :unprocessable_entity)
    end

    message = persist_outbound(
      sid:    result[:sid],
      status: result[:status],
      body:   rendered_body,
      extra:  { template_sid: template.content_sid, template_name: template.friendly_name }
    )
    message.media.attach(media_blob) if media_blob

    UserKpiRecord.track!(current_user&.id, :whatsapp_messages_sent)
    WhatsappUsBroadcaster.broadcast(message)
    render_success({ message: serialize_message(message) }, 'Template sent')
  end

  # POST /api/v2/whatsapp_us/customers/:customer_id/mark_read
  # Body (optional):
  #   up_to_message_id: integer   — mark inbound unreads with id <= this
  #   up_to_timestamp:  ISO8601   — mark inbound unreads with timestamp <= this
  # If neither is given, marks every inbound unread for this customer.
  # Returns { marked, remaining_unread }.
  def mark_read
    scope = @customer.whatsapp_messages.where(direction: 'inbound', status: 'received')

    if params[:up_to_message_id].present?
      scope = scope.where('id <= ?', params[:up_to_message_id].to_i)
    elsif params[:up_to_timestamp].present?
      cutoff = Time.iso8601(params[:up_to_timestamp]) rescue nil
      return render_error('Invalid up_to_timestamp', nil, :unprocessable_entity) unless cutoff
      scope = scope.where('timestamp <= ?', cutoff)
    end

    marked = scope.update_all(status: 'read', updated_at: Time.current)
    remaining = @customer.whatsapp_messages
                          .where(direction: 'inbound', status: 'received')
                          .count

    render_success({ marked: marked, remaining_unread: remaining }, 'Marked as read')
  end

  # GET /api/v2/whatsapp_us/latest?after_id=N
  # Cross-conversation delta: every message (any direction, any customer the
  # caller can see) with id > after_id. Used to catch up after a reconnect or
  # when the app comes back to the foreground without firing the ActionCable
  # broadcast. If after_id is missing/0 we cap at the last 50 to avoid
  # accidentally returning everything.
  def latest
    after_id = params[:after_id].to_i
    visible_customer_ids = accessible_customers.select(:id)

    base = WhatsappMessage.where(customer_id: visible_customer_ids).order(:id)
    base = base.where('whatsapp_messages.id > ?', after_id) if after_id.positive?
    base = base.limit(50) unless after_id.positive?

    render_success({
      messages:  base.map { |m| serialize_message(m) },
      latest_id: base.last&.id || after_id
    }, 'Latest messages retrieved')
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

  # Opt-in pagination: client sends `per_page` (and optionally `page`, 1-indexed).
  # If `per_page` is absent or non-positive, no limit is applied and pagination
  # is returned as nil so the caller knows the response wasn't sliced.
  #
  # Returns [scoped_relation, pagination_meta_or_nil].
  def paginate(relation, total)
    per_page = params[:per_page].to_i
    return [relation, nil] unless per_page.positive?

    page  = [params[:page].to_i, 1].max
    pages = (total.to_f / per_page).ceil
    scoped = relation.limit(per_page).offset((page - 1) * per_page)

    [scoped, { page: page, per_page: per_page, total: total, total_pages: pages }]
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
    WhatsappUsBroadcaster.broadcast(message)
    render_success({ message: serialize_message(message) }, 'Message sent')
  end

  def send_media_via_twilio(file, caption)
    validation = validate_media(file)
    return render_error(validation[:error], nil, :unprocessable_entity) unless validation[:valid]

    normalized = WhatsappAudioTranscoder.normalize(file)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: normalized[:io],
      filename: normalized[:filename],
      content_type: normalized[:content_type]
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
    WhatsappUsBroadcaster.broadcast(message)
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
    audio/mpeg audio/mp3 audio/ogg audio/wav audio/m4a audio/x-m4a
    audio/flac audio/webm audio/aac audio/mp4 audio/amr audio/3gpp
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

    bare = bare_content_type(file.content_type)
    unless ALLOWED_MEDIA_TYPES.include?(bare)
      return { valid: false, error: "File type '#{bare}' is not supported" }
    end
    if file.size > MAX_MEDIA_BYTES
      return { valid: false, error: "File is too large (max #{MAX_MEDIA_BYTES / 1.megabyte}MB)" }
    end

    { valid: true }
  end

  # Strip parameters like "audio/mp4; codecs=mp4a.40.2" → "audio/mp4" so the
  # allow-list comparison isn't defeated by a benign codec hint.
  def bare_content_type(ct)
    ct.to_s.split(';').first.to_s.strip.downcase
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
