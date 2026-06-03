require 'open3'
require 'shellwords'
require 'tempfile'

# Normalizes an uploaded audio file into a format Twilio WhatsApp will accept.
#
# Twilio's outbound media for WhatsApp supports these audio types only:
#   audio/aac, audio/mp4, audio/mpeg, audio/amr, audio/ogg (Opus only)
#
# Chrome's MediaRecorder produces audio/webm (opus), which Twilio rejects.
# When we see audio/webm (or anything else outside the allow-list), we shell
# out to ffmpeg and transcode to ogg/opus. If ffmpeg isn't installed or the
# transcode fails, we pass the file through unchanged — better to attempt the
# send than block it.
#
# Returns { io:, filename:, content_type: } — the shape
# ActiveStorage::Blob.create_and_upload! expects.
class WhatsappAudioTranscoder
  TWILIO_AUDIO_OK = %w[audio/aac audio/mp4 audio/mpeg audio/amr audio/ogg audio/3gpp].freeze

  # Common content-type aliases browsers/mobile send → the canonical Twilio
  # form. Mapping lets the file pass through unchanged but uploaded with the
  # canonical content-type so Twilio is happy.
  ALIAS_MAP = {
    'audio/x-m4a' => 'audio/mp4',
    'audio/mp3'   => 'audio/mpeg'
  }.freeze

  def self.normalize(uploaded_file)
    new(uploaded_file).normalize
  end

  def initialize(uploaded_file)
    @file         = uploaded_file
    @content_type = bare(uploaded_file.content_type)
    @filename     = uploaded_file.original_filename.to_s
  end

  def normalize
    return passthrough unless audio?
    return passthrough(ALIAS_MAP[@content_type] || @content_type) if twilio_compatible?

    transcoded = transcode_to_ogg
    return transcoded if transcoded

    Rails.logger.warn("[WhatsappAudio] ffmpeg unavailable or failed; sending #{@content_type} as-is")
    passthrough
  end

  private

  # Strip "audio/mp4; codecs=mp4a.40.2" → "audio/mp4".
  def bare(ct)
    ct.to_s.split(';').first.to_s.strip.downcase
  end

  def audio?
    @content_type.start_with?('audio/')
  end

  def twilio_compatible?
    canonical = ALIAS_MAP[@content_type] || @content_type
    TWILIO_AUDIO_OK.include?(canonical)
  end

  def passthrough(content_type_override = nil)
    { io: @file.tempfile, filename: @filename, content_type: content_type_override || @content_type }
  end

  def transcode_to_ogg
    input  = @file.tempfile.path
    output = Tempfile.new(['wa-voice', '.ogg'], binmode: true)
    output.close

    cmd = [
      'ffmpeg', '-y', '-loglevel', 'error',
      '-i', input,
      '-vn',
      '-c:a', 'libopus',
      '-b:a', '32k',
      '-f', 'ogg',
      output.path
    ]
    _stdout, stderr, status = Open3.capture3(*cmd)

    if status.success? && File.size?(output.path).to_i.positive?
      base = File.basename(@filename, '.*').presence || 'voice-note'
      { io: File.open(output.path, 'rb'), filename: "#{base}.ogg", content_type: 'audio/ogg' }
    else
      Rails.logger.warn("[WhatsappAudio] ffmpeg failed (#{status.exitstatus}): #{stderr.to_s.truncate(300)}")
      File.unlink(output.path) if File.exist?(output.path)
      nil
    end
  rescue Errno::ENOENT
    # ffmpeg not on PATH
    nil
  end
end
