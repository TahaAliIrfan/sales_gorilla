# Syncs WhatsApp Content templates from Twilio's Content API into the
# whatsapp_templates table. We list only approved WhatsApp templates so the
# UI can offer them as send-options outside the 24h freeform window.
#
#   https://www.twilio.com/docs/content-api/content-api-resources#contentandapprovals
require 'net/http'
require 'uri'
require 'json'

class TwilioWhatsappTemplatesService
  CONTENT_AND_APPROVALS_URL = 'https://content.twilio.com/v1/ContentAndApprovals'.freeze

  def initialize
    @account_sid = Rails.application.credentials.dig(:TWILIO_ACCOUNT_SID)
    @auth_token  = Rails.application.credentials.dig(:TWILIO_AUTH_TOKEN)
    raise 'Twilio credentials not configured' unless @account_sid && @auth_token
  end

  # Fetches approved WhatsApp templates from Twilio and upserts them.
  # Returns a result hash: { success:, synced:, skipped:, error: }.
  def sync!
    synced = 0
    skipped = 0
    next_url = "#{CONTENT_AND_APPROVALS_URL}?PageSize=50"

    while next_url
      response = http_get(next_url)
      return { success: false, error: response[:error] } unless response[:success]

      data = response[:body]
      Array(data['contents']).each do |c|
        approval = whatsapp_approval(c)
        if approval && approval['status'].to_s.downcase == 'approved'
          upsert(c, approval)
          synced += 1
        else
          skipped += 1
        end
      end

      next_url = data.dig('meta', 'next_page_url').presence
    end

    { success: true, synced: synced, skipped: skipped }
  rescue StandardError => e
    Rails.logger.error("[TwilioWhatsappTemplates] sync failed: #{e.class} #{e.message}")
    { success: false, error: e.message }
  end

  private

  # Twilio's ContentAndApprovals returns `approval_requests` as a Hash
  # ({"status" => "approved", "category" => "UTILITY", ...}); some legacy
  # accounts have observed it as an Array. Be defensive about both shapes.
  def whatsapp_approval(content)
    raw = content['approval_requests']
    return nil if raw.blank?

    if raw.is_a?(Hash)
      raw
    elsif raw.is_a?(Array)
      raw.find { |a| a.is_a?(Hash) && a['channel'].to_s.downcase == 'whatsapp' } || raw.first
    end
  end

  def upsert(content, approval)
    template = WhatsappTemplate.find_or_initialize_by(content_sid: content['sid'])
    template.friendly_name   = content['friendly_name']
    template.language        = content['language']
    template.category        = approval['category']
    template.approval_status = approval['status']
    template.types           = content['types'] || {}
    template.variables       = content['variables'] || {}
    template.body            = extract_body(content['types'])
    template.last_synced_at  = Time.current
    template.save!
  end

  # Templates have many possible content types (twilio/text, twilio/quick-reply,
  # twilio/card, etc.). For preview purposes we pull whichever has a `body`,
  # preferring plain text.
  def extract_body(types)
    return nil if types.blank?

    if types['twilio/text'].is_a?(Hash) && types['twilio/text']['body'].present?
      return types['twilio/text']['body']
    end

    types.each_value do |def_|
      next unless def_.is_a?(Hash)
      return def_['body'] if def_['body'].present?
    end
    nil
  end

  def http_get(url)
    uri = URI.parse(url)
    req = Net::HTTP::Get.new(uri.request_uri)
    req.basic_auth(@account_sid, @auth_token)

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

    if res.is_a?(Net::HTTPSuccess)
      { success: true, body: JSON.parse(res.body) }
    else
      { success: false, error: "Twilio responded #{res.code}: #{res.body.to_s.truncate(200)}" }
    end
  end
end
