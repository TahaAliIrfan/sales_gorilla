require 'net/http'
require 'uri'
require 'stringio'
require 'open3'
require 'tempfile'

# Downloads media attached to an inbound Twilio WhatsApp message and attaches it
# to the WhatsappMessage record. Twilio media URLs require account auth to fetch
# and redirect to the underlying storage, so this runs out-of-band rather than
# blocking the webhook response.
class TwilioWhatsappMediaWorker
  include Sidekiq::Worker

  sidekiq_options retry: 5, queue: 'whatsapp_analysis'

  MAX_REDIRECTS = 5

  # Twilio delivers WhatsApp voice notes as Ogg/Opus, which iOS Safari and email
  # link previewers can't decode in that container. We transcode to AAC in an
  # M4A container — playable on every major client.
  TRANSCODE_FROM_TYPES = %w[audio/ogg audio/opus application/ogg].freeze

  # Preferred file extension per content type, used when we have to invent a
  # filename (inbound messages with no caption arrive as "[N media attachment(s)]").
  # Rack::Mime#invert is non-deterministic for content-types with multiple
  # registered extensions (e.g. audio/mp4 maps to both .mp4 and .m4a).
  PREFERRED_EXT = {
    'audio/mp4'  => '.m4a',
    'audio/aac'  => '.aac',
    'audio/mpeg' => '.mp3',
    'audio/ogg'  => '.ogg'
  }.freeze

  def perform(message_id)
    message = WhatsappMessage.find_by(id: message_id)
    return unless message
    return if message.media.attached?

    item = Array(message.metadata&.dig('media')).find { |m| m['url'].present? }
    return unless item

    downloaded = download(item['url'])
    return unless downloaded

    content_type = downloaded[:content_type].presence || item['content_type']
    payload      = maybe_transcode_to_aac(downloaded[:body], content_type)
    filename     = build_filename(message, payload[:content_type])

    message.media.attach(
      io: StringIO.new(payload[:body]),
      filename: filename,
      content_type: payload[:content_type]
    )

    # Replace the "[N media attachment(s)]" placeholder body when there's no caption.
    message.update(body: filename) if message.body.blank? || message.body.to_s.start_with?('[')

    Rails.logger.info("[TwilioWhatsapp] attached inbound media to message #{message.id} (#{filename})")

    # The first broadcast (from TwilioWhatsappController#inbound) went out with
    # media_url=nil while we were downloading the file. Re-broadcast now so
    # clients can upsert by id and render the attachment without re-polling.
    WhatsappUsBroadcaster.broadcast(message.reload)
  end

  private

  def download(url, limit = MAX_REDIRECTS)
    return nil if limit.zero?

    uri  = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    request = Net::HTTP::Get.new(uri)
    # Only send Twilio credentials to Twilio hosts; the redirect target is a
    # signed storage URL that must not receive the auth header.
    request.basic_auth(account_sid, auth_token) if uri.host.to_s.end_with?('twilio.com')

    response = http.request(request)

    case response
    when Net::HTTPSuccess
      { body: response.body, content_type: response['content-type'] }
    when Net::HTTPRedirection
      download(response['location'], limit - 1)
    else
      Rails.logger.error("[TwilioWhatsapp] media download failed (#{response.code}) for #{uri.host}")
      nil
    end
  end

  def build_filename(message, content_type)
    bare = content_type.to_s.split(';').first.to_s.strip.downcase
    ext  = PREFERRED_EXT[bare] || Rack::Mime::MIME_TYPES.invert[bare] # ".pdf", ".jpeg", ...

    # Twilio passes the original document name in Body for inbound documents.
    original = message.body.to_s.strip
    return sanitize_filename(original) if original.present? && File.extname(original).present?

    "wa_#{message.message_id}#{ext}"
  end

  # Transcodes Ogg/Opus voice notes to AAC/M4A so iOS Safari, email link
  # previews, and other web players can decode them. Falls through to the
  # original bytes if ffmpeg is missing or the encode fails — better to deliver
  # the file as-is than to drop it.
  def maybe_transcode_to_aac(body, content_type)
    bare = content_type.to_s.split(';').first.to_s.strip.downcase
    return { body: body, content_type: content_type } unless TRANSCODE_FROM_TYPES.include?(bare)

    input  = Tempfile.new(['wa-in', '.oga'], binmode: true)
    output = Tempfile.new(['wa-out', '.m4a'], binmode: true)
    input.write(body)
    input.close
    output.close

    cmd = [
      'ffmpeg', '-y', '-loglevel', 'error',
      '-i', input.path,
      '-vn',
      '-c:a', 'aac',
      '-b:a', '64k',
      '-movflags', '+faststart',
      output.path
    ]
    _stdout, stderr, status = Open3.capture3(*cmd)

    if status.success? && File.size?(output.path).to_i.positive?
      { body: File.binread(output.path), content_type: 'audio/mp4' }
    else
      Rails.logger.warn("[TwilioWhatsapp] ffmpeg transcode failed (#{status.exitstatus}): #{stderr.to_s.truncate(200)}")
      { body: body, content_type: content_type }
    end
  rescue Errno::ENOENT
    # ffmpeg not on PATH — fall through to the original.
    { body: body, content_type: content_type }
  ensure
    [input, output].each { |f| File.unlink(f.path) if f && File.exist?(f.path) }
  end

  def sanitize_filename(name)
    File.basename(name).gsub(%r{[/\\]}, '_').strip
  end

  def account_sid
    Rails.application.credentials.dig(:TWILIO_ACCOUNT_SID)
  end

  def auth_token
    Rails.application.credentials.dig(:TWILIO_AUTH_TOKEN)
  end
end
