# Dashboard UI for the Twilio-backed "WhatsApp US" channel on the customer
# show page. Reads/writes the whatsapp_messages table. Inbound messages arrive
# via TwilioWhatsappController (webhook); this controller lists them and sends
# outbound replies through TwilioWhatsappService.
class WhatsappUsController < ApplicationController
  before_action :require_login
  before_action :set_customer
  after_action :verify_authorized

  # GET /customers/:customer_id/whatsapp_us.json
  def index
    authorize @customer, :show?

    refresh_stale_outbound_statuses
    ensure_phone_lookup

    render json: {
      messages: @customer.whatsapp_messages.reload.order(:timestamp, :created_at).map { |m| serialize(m) },
      window_open: @customer.whatsapp_us_window_open?,
      last_inbound_at: @customer.whatsapp_us_last_inbound_at&.iso8601,
      phone_unreachable: @customer.whatsapp_phone_unreachable?,
      phone_unreachable_reason: @customer.whatsapp_reachability_reason,
      phone_line_type: @customer.phone_line_type,
      phone_carrier:   @customer.phone_carrier,
      phone_lookup_checked_at: @customer.phone_lookup_checked_at&.iso8601
    }
  end

  # POST /customers/:customer_id/whatsapp_us/lookup_phone
  # Manually re-runs Twilio Lookup on the customer's phone (e.g. after a number
  # change). Returns the refreshed reachability info.
  def lookup_phone
    authorize @customer, :show?
    return render_error("Customer has no phone number") if @customer.phone.blank?

    result = PhoneLookupService.new.check!(@customer, force: true)
    return render_error(result[:error] || "Lookup failed", :unprocessable_entity) unless result[:success]

    render json: {
      success: true,
      phone_unreachable: @customer.reload.whatsapp_phone_unreachable?,
      phone_unreachable_reason: @customer.whatsapp_reachability_reason,
      phone_line_type: @customer.phone_line_type,
      phone_carrier:   @customer.phone_carrier,
      phone_lookup_checked_at: @customer.phone_lookup_checked_at&.iso8601
    }
  end

  # POST /customers/:customer_id/whatsapp_us
  def create
    authorize @customer, :show?

    file = params[:file]
    body = params[:body].to_s.strip
    return render_error("Customer has no phone number") if @customer.phone.blank?
    return render_error("Message cannot be blank") if body.blank? && file.blank?

    if @customer.whatsapp_phone_unreachable?
      return render_error("Can't send — #{@customer.whatsapp_reachability_reason}", :forbidden)
    end

    unless @customer.whatsapp_us_window_open?
      return render_error("The 24-hour reply window has closed. The customer must message first before you can send a freeform message.", :forbidden)
    end

    file.present? ? send_media_message(file, body) : send_text_message(body)
  end

  # POST /customers/:customer_id/whatsapp_us/sync_chat
  # Pulls every Twilio WhatsApp message exchanged with this customer (both
  # directions) and upserts them into whatsapp_messages by message_id. Existing
  # rows keep their attached media and locally-tracked metadata.
  def sync_chat
    authorize @customer, :show?
    return render_error("Customer has no phone number") if @customer.phone.blank?

    twilio_msgs = TwilioWhatsappService.new.list_messages_for(phone: @customer.phone)
    created, updated = 0, 0
    twilio_msgs.each do |t|
      change = upsert_from_twilio(t)
      created += 1 if change == :created
      updated += 1 if change == :updated
    end

    render json: {
      success: true,
      synced: twilio_msgs.size,
      created: created,
      updated: updated,
      messages: @customer.whatsapp_messages.reload.order(:timestamp, :created_at).map { |m| serialize(m) },
      window_open: @customer.whatsapp_us_window_open?,
      last_inbound_at: @customer.whatsapp_us_last_inbound_at&.iso8601
    }
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
    return render_error("Admins only", :forbidden) unless current_user&.admin?

    result = TwilioWhatsappTemplatesService.new.sync!
    return render_error(result[:error] || "Sync failed", :unprocessable_entity) unless result[:success]

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
    return render_error("Customer has no phone number") if @customer.phone.blank?
    if @customer.whatsapp_phone_unreachable?
      return render_error("Can't send — #{@customer.whatsapp_reachability_reason}", :forbidden)
    end

    template = WhatsappTemplate.approved.find_by(content_sid: params[:content_sid])
    return render_error("Template not found or not approved", :not_found) unless template

    variables = sanitize_variables(template, params[:variables])

    # Templates with a hardcoded media URL (no variable in the media field)
    # can't have their media swapped at send time — Twilio's Content API
    # ignores `media_url` when `content_sid` is set. So we either substitute a
    # user upload into a media variable, or there's nothing useful to do with
    # an upload.
    file = params[:file]
    media_blob = nil

    if template.requires_media_upload?
      return render_error("This template requires a file attachment") if file.blank?

      validation = validate_media(file)
      return render_error(validation[:error]) unless validation[:valid]

      media_blob = ActiveStorage::Blob.create_and_upload!(
        io: file.tempfile,
        filename: file.original_filename,
        content_type: file.content_type
      )
      # Pass the Active Storage signed_id, not a presigned S3 URL. The Twilio
      # template's Media URL is `https://crm.tecaudex.com/wa/media/{{1}}`, so
      # Twilio assembles the final URL and Meta hits our public redirect
      # endpoint (WhatsappMediaController) which 302s to S3.
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
      return render_error(result[:error] || "Failed to send template", :unprocessable_entity)
    end

    message = persist_outbound(sid: result[:sid], status: result[:status], body: rendered_body)
    message.media.attach(media_blob) if media_blob
    # Stash a marker so the chat UI can render a "template" badge later if we want.
    message.update(metadata: (message.metadata || {}).merge(
      template_sid:  template.content_sid,
      template_name: template.friendly_name
    ))

    UserKpiRecord.track!(current_user&.id, :whatsapp_messages_sent)
    WhatsappUsBroadcaster.broadcast(message)
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
      content_sid:           t.content_sid,
      friendly_name:         t.friendly_name,
      language:              t.language,
      category:              t.category,
      body:                  t.body,
      variable_keys:         t.variable_keys,
      text_variable_keys:    t.text_variable_keys,
      has_media:             t.has_media?,
      requires_media_upload: t.requires_media_upload?,
      last_synced_at:        t.last_synced_at&.iso8601
    }
  end


  # Text-only outbound message.
  def send_text_message(body)
    result = TwilioWhatsappService.new.send_text(to_phone: @customer.phone, body: body)
    return render_error(result[:error] || "Failed to send message", :unprocessable_entity) unless result[:success]

    message = persist_outbound(sid: result[:sid], status: result[:status], body: body)
    UserKpiRecord.track!(current_user&.id, :whatsapp_messages_sent)
    WhatsappUsBroadcaster.broadcast(message)
    respond_with_sent(message)
  end

  # Outbound message with an uploaded document/image/voice note. The file is
  # stored first so Twilio can fetch it from a signed URL, then the message is
  # persisted with the same blob attached. Audio formats Twilio doesn't accept
  # (e.g. Chrome's audio/webm) are transcoded to ogg/opus before upload.
  def send_media_message(file, caption)
    validation = validate_media(file)
    return render_error(validation[:error]) unless validation[:valid]

    normalized = WhatsappAudioTranscoder.normalize(file)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: normalized[:io],
      filename: normalized[:filename],
      content_type: normalized[:content_type]
    )

    result = TwilioWhatsappService.new.send_media(
      to_phone: @customer.phone,
      media_url: blob.url(expires_in: 1.hour),
      body: caption.presence
    )

    unless result[:success]
      blob.purge_later
      return render_error(result[:error] || "Failed to send file", :unprocessable_entity)
    end

    message = persist_outbound(
      sid: result[:sid],
      status: result[:status],
      body: caption.presence || file.original_filename
    )
    message.media.attach(blob)

    UserKpiRecord.track!(current_user&.id, :whatsapp_messages_sent)
    WhatsappUsBroadcaster.broadcast(message)
    respond_with_sent(message)
  end

  # Existing callers expect JSON (chat panel / mobile API). The Relay lead
  # workspace composer requests turbo_stream so the new bubble appends to the
  # conversation canvas in place. Both share the same persisted message.
  def respond_with_sent(message)
    respond_to do |format|
      format.json { render json: { success: true, message: serialize(message) } }
      format.turbo_stream do
        render turbo_stream: turbo_stream.before(
          "conversation_tail",
          partial: "customers/relay/whatsapp_bubble",
          locals: { message: message }
        )
      end
    end
  end

  def persist_outbound(sid:, status:, body:)
    @customer.whatsapp_messages.create!(
      message_id: sid,
      remote_id:  @customer.phone,
      body:       body,
      direction:  "outbound",
      status:     status || "queued",
      timestamp:  Time.current,
      metadata:   { provider: "twilio", to: "whatsapp:#{@customer.phone}", from: TwilioWhatsappService::FROM, sent_by_user_id: current_user&.id }
    )
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

  # WhatsApp caps media at 16MB; we mirror that.
  MAX_MEDIA_BYTES = 16.megabytes

  def validate_media(file)
    return { valid: false, error: "No file provided" } unless file.respond_to?(:content_type)

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
    ct.to_s.split(";").first.to_s.strip.downcase
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
      display_status: display_status_for(message),
      error_code: message.metadata&.dig("error_code"),
      error_message: message.metadata&.dig("error_message"),
      timestamp: (message.timestamp || message.created_at).iso8601,
      formatted_time: (message.timestamp || message.created_at).strftime("%b %d, %H:%M"),
      media_url: attached ? rails_blob_path(attached, only_path: true) : nil,
      media_filename: attached&.filename.to_s.presence,
      media_content_type: attached&.content_type,
      media: message.metadata&.dig("media") || []
    }
  end

  # User-friendly bucket for the status badge: pending | sent | delivered | failed.
  def display_status_for(message)
    return nil if message.direction != "outbound"

    case message.status.to_s.downcase
    when "delivered", "read"                  then "delivered"
    when "sent"                               then "sent"
    when "failed", "undelivered"              then "failed"
    else "pending"
    end
  end

  NON_FINAL_OUTBOUND_STATUSES = %w[queued sending accepted scheduled].freeze

  # Re-poll Twilio for any recent outbound message whose webhook never landed
  # (e.g. dev callbacks can't reach localhost). Rate-limited per-message so
  # we don't hammer Twilio on every 15s UI poll.
  def refresh_stale_outbound_statuses
    stale = @customer.whatsapp_messages
              .where(direction: "outbound", status: NON_FINAL_OUTBOUND_STATUSES)
              .where("created_at > ?", 1.hour.ago)
              .to_a
              .reject { |m| recently_refreshed?(m) || m.message_id.blank? }

    return if stale.empty?

    svc = TwilioWhatsappService.new
    stale.each do |m|
      result = svc.refresh_status(m.message_id)
      next unless result[:success]

      m.update(
        status:   result[:status] || m.status,
        metadata: (m.metadata || {}).merge(
          error_code:           result[:error_code],
          error_message:        result[:error_message],
          status_refreshed_at:  Time.current.iso8601
        ).compact
      )
    end
  rescue StandardError => e
    Rails.logger.warn("[WhatsappUs] status refresh batch failed: #{e.class} #{e.message}")
  end

  # Takes a Twilio MessageInstance and writes it into whatsapp_messages,
  # creating or updating by Twilio SID. Returns :created, :updated, or :unchanged.
  def upsert_from_twilio(t)
    return :unchanged if t.sid.blank?

    is_inbound = t.direction.to_s == "inbound"
    customer_addr = "whatsapp:#{@customer.phone}"

    message = @customer.whatsapp_messages.find_or_initialize_by(message_id: t.sid)
    new_record = message.new_record?

    message.assign_attributes(
      remote_id: (is_inbound ? t.from : t.to).to_s.sub(/\Awhatsapp:/, ""),
      body:      t.body.presence || (t.num_media.to_i.positive? ? "[#{t.num_media} media attachment(s)]" : nil),
      direction: is_inbound ? "inbound" : "outbound",
      status:    t.status,
      timestamp: t.date_sent || t.date_created || Time.current,
      metadata:  (message.metadata || {}).merge(
        provider:      "twilio",
        from:          t.from,
        to:            t.to,
        error_code:    t.error_code,
        error_message: t.error_message,
        num_media:     t.num_media.to_i,
        synced_at:     Time.current.iso8601
      ).compact
    )

    changed = message.changed?
    message.save! if changed || new_record

    # Inbound media we haven't downloaded yet → enqueue the existing worker.
    if is_inbound && t.num_media.to_i.positive? && !message.media.attached?
      TwilioWhatsappMediaWorker.perform_async(message.id)
    end

    return :created if new_record
    return :updated if changed
    :unchanged
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[WhatsappUs#sync_chat] skip #{t.sid}: #{e.message}")
    :unchanged
  end

  # Kicks off a Twilio Lookup the first time a customer's chat is viewed (and
  # again every CACHE_TTL). One Twilio API call per customer per month is cheap
  # insurance against sending into a black hole.
  def ensure_phone_lookup
    return if @customer.phone.blank?
    return if @customer.phone_lookup_checked_at.present? &&
              @customer.phone_lookup_checked_at > PhoneLookupService::CACHE_TTL.ago

    PhoneLookupService.new.check!(@customer)
  end

  def recently_refreshed?(message)
    last = message.metadata&.dig("status_refreshed_at")
    return false if last.blank?
    Time.iso8601(last) > 30.seconds.ago
  rescue ArgumentError
    false
  end


  def render_error(message, status = :unprocessable_entity)
    respond_to do |format|
      format.json { render json: { success: false, error: message }, status: status }
      # Relay composer (turbo_stream) — surface the reason as a flash redirect
      # back to the workspace rather than a raw JSON body Turbo can't render.
      format.turbo_stream { redirect_to customer_path(@customer), alert: message }
      format.html { redirect_to customer_path(@customer), alert: message }
    end
  end
end
