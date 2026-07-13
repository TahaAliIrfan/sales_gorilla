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
  CONTENT_URL = 'https://content.twilio.com/v1/Content'.freeze
  CATEGORIES  = %w[UTILITY MARKETING AUTHENTICATION].freeze

  def initialize
    @account_sid = Rails.application.credentials.dig(:TWILIO_ACCOUNT_SID)
    @auth_token  = Rails.application.credentials.dig(:TWILIO_AUTH_TOKEN)
    raise 'Twilio credentials not configured' unless @account_sid && @auth_token
  end

  # Creates a text WhatsApp Content template on Twilio and submits it to Meta
  # for approval. Meta approval is asynchronous, so the template lands here as
  # pending and only becomes usable in campaigns once approved (then synced).
  # Returns { success:, sid:, status:, error: }.
  def create_template(friendly_name:, body:, category:, language: 'en')
    return { success: false, error: 'Name is required' }         if friendly_name.blank?
    return { success: false, error: 'Message body is required' } if body.blank?
    unless CATEGORIES.include?(category.to_s.upcase)
      return { success: false, error: "Category must be one of #{CATEGORIES.join(', ')}" }
    end

    variables = extract_variables(body)
    create = http_post_json(CONTENT_URL, {
      friendly_name: friendly_name,
      language: language.presence || 'en',
      variables: variables,
      types: { 'twilio/text' => { body: body } }
    })
    return { success: false, error: create[:error] } unless create[:success]

    content = create[:body]
    sid = content['sid']

    approval = http_post_json("#{CONTENT_URL}/#{sid}/ApprovalRequests/whatsapp", {
      name: whatsapp_name(friendly_name),
      category: category.to_s.upcase
    })
    status = approval[:success] ? (approval[:body]['status'].presence || 'received') : 'pending'

    upsert_created(content, category.to_s.upcase, status)

    { success: true, sid: sid, status: status, approval_error: (approval[:error] unless approval[:success]) }
  rescue StandardError => e
    Rails.logger.error("[TwilioWhatsappTemplates] create failed: #{e.class} #{e.message}")
    { success: false, error: e.message }
  end

  # Deletes the Content template from Twilio (which withdraws it from WhatsApp)
  # and removes the local row. Returns { success:, error: }.
  def delete_template(content_sid)
    return { success: false, error: 'content_sid is required' } if content_sid.blank?

    result = http_delete("#{CONTENT_URL}/#{content_sid}")
    return { success: false, error: result[:error] } unless result[:success]

    WhatsappTemplate.where(content_sid: content_sid).destroy_all
    { success: true }
  rescue StandardError => e
    Rails.logger.error("[TwilioWhatsappTemplates] delete failed: #{e.class} #{e.message}")
    { success: false, error: e.message }
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

  # Numbered/named {{token}} placeholders in the body become Twilio `variables`
  # with a sample value each (Twilio requires a sample for approval preview).
  def extract_variables(body)
    body.to_s.scan(/\{\{\s*(\w+)\s*\}\}/).flatten.uniq.index_with { |k| "Sample #{k}" }
  end

  # Meta template names must be lowercase, alphanumeric plus underscores.
  def whatsapp_name(friendly_name)
    friendly_name.to_s.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/_+/, '_').gsub(/\A_|_\z/, '').first(512)
  end

  # Store a just-created template locally as pending; the next sync flips it to
  # approved once Meta approves.
  def upsert_created(content, category, status)
    template = WhatsappTemplate.find_or_initialize_by(content_sid: content['sid'])
    template.friendly_name   = content['friendly_name']
    template.language        = content['language']
    template.category        = category
    template.approval_status = status
    template.types           = content['types'] || {}
    template.variables       = content['variables'] || {}
    template.body            = extract_body(content['types'])
    template.last_synced_at  = Time.current
    template.save!
  end

  def http_post_json(url, payload)
    uri = URI.parse(url)
    req = Net::HTTP::Post.new(uri.request_uri)
    req.basic_auth(@account_sid, @auth_token)
    req['Content-Type'] = 'application/json'
    req.body = payload.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

    if res.is_a?(Net::HTTPSuccess)
      { success: true, body: (JSON.parse(res.body) rescue {}) }
    else
      { success: false, error: twilio_error(res) }
    end
  end

  def http_delete(url)
    uri = URI.parse(url)
    req = Net::HTTP::Delete.new(uri.request_uri)
    req.basic_auth(@account_sid, @auth_token)

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
    res.is_a?(Net::HTTPSuccess) ? { success: true } : { success: false, error: twilio_error(res) }
  end

  # Twilio errors return JSON like {"message": "...", "code": 20404}.
  def twilio_error(res)
    parsed = JSON.parse(res.body) rescue nil
    parsed&.dig('message').presence || "Twilio responded #{res.code}: #{res.body.to_s.truncate(200)}"
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
