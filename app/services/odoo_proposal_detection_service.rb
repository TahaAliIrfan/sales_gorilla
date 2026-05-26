require 'net/http'
require 'json'
require 'base64'

# Analyses a free-form requirements input (text / PDF / image / docx) and returns
# a structured set of detected standard Odoo modules and suggested custom modules,
# plus inferred client context (industry, size, pain points).
#
# Returns a Hash:
#   {
#     "modules"        => ["crm", "inventory", ...],          # standard module keys
#     "custom_modules" => [{ "label" => "...", "description" => "...", "impl_cost" => 50000 }, ...],
#     "industry"       => "Manufacturing",
#     "company_size"   => "51-200",
#     "pain_points"    => ["Inventory tracking and stock visibility", ...]
#   }
# Or nil on API/parse failure (caller renders a clean error).
class OdooProposalDetectionService
  MAX_TEXT_CHARS = 60_000
  MAX_FILE_BYTES = 12 * 1024 * 1024  # 12 MB

  IMAGE_TYPES = {
    'image/png'  => 'image/png',
    'image/jpeg' => 'image/jpeg',
    'image/jpg'  => 'image/jpeg',
    'image/gif'  => 'image/gif',
    'image/webp' => 'image/webp'
  }.freeze

  PDF_TYPE   = 'application/pdf'.freeze
  DOCX_TYPE  = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'.freeze
  TEXT_TYPES = %w[text/plain text/markdown].freeze

  attr_reader :error

  def initialize(text: nil, file: nil)
    @text  = text.to_s.strip
    @file  = file
    @api_key = Rails.application.credentials.dig(:ANTHROPIC_API_KEY) || ENV['ANTHROPIC_API_KEY']
    @model   = 'claude-sonnet-4-6'
    @error   = nil
  end

  def analyze
    if @api_key.blank?
      @error = 'Anthropic API key not configured.'
      return nil
    end
    if @text.blank? && @file.blank?
      @error = 'Provide text or upload a file.'
      return nil
    end

    user_content = build_user_content
    return nil if user_content.nil?

    response = call_claude(user_content)
    parsed = parse_json(response)
    return nil unless parsed.is_a?(Hash)

    normalise(parsed)
  end

  private

  def module_catalog_summary
    OdooProposal::MODULES.map do |category, mods|
      lines = mods.map { |m| "    - #{m[:key]} (#{m[:label]}): #{m[:description]}" }.join("\n")
      "  #{category}:\n#{lines}"
    end.join("\n")
  end

  def system_prompt
    <<~SYS
      You are an Odoo ERP solution architect at Tecaudex (an Official Odoo Partner in Pakistan).
      Your job is to read a client requirements brief and recommend which Odoo modules they need.

      You have two outputs:
      1) Standard modules — choose from the official catalog below using the exact `key` (snake_case).
      2) Custom modules — anything the client needs that ISN'T covered by the standard catalog.
         These represent extra Tecaudex development effort (custom Odoo modules, integrations,
         third-party API work, bespoke screens). Each must have a label, a 1-sentence description
         scoped to this client, and a realistic PKR implementation cost.

      ## Official Odoo module catalog (use these exact keys for "modules")
      #{module_catalog_summary}

      ## Custom module cost guidance (PKR, one-time implementation)
      - Minor screen / report / workflow tweak: 20,000 – 40,000
      - Custom Odoo module of medium complexity: 60,000 – 120,000
      - Third-party API integration (CRM/payments/local courier/SMS gateway etc.): 80,000 – 180,000
      - Large bespoke subsystem (e.g. custom production planning UI): 200,000 – 500,000
      Pick a single integer per custom module based on the described scope. Be realistic for Pakistan rates.

      ## Inference rules
      - Detect industry from the catalog: Manufacturing, Retail / eCommerce, Distribution / Wholesale,
        Services / Consulting, Healthcare, Education, Construction, Real Estate, Hospitality,
        Logistics / Transportation, Technology / Software, Non-Profit, Other.
      - Detect company size as one of: 1-10, 11-50, 51-200, 201-500, 500+. If unclear, omit.
      - Detect pain points using these exact phrasings where applicable:
        Manual data entry / spreadsheet chaos,
        Inventory tracking and stock visibility,
        Sales pipeline & lead management,
        Customer follow-up gaps,
        Payroll & HR overhead,
        Multi-location / multi-branch coordination,
        Reporting & business analytics,
        Disconnected systems (no single source of truth),
        Field service / dispatch coordination,
        Manufacturing floor & production visibility,
        Customer support & ticket backlog,
        Marketing campaign tracking & ROI,
        Procurement & vendor management,
        Project & timesheet management,
        Compliance & audit trail.

      ## Output format
      Return STRICTLY VALID JSON only, with this exact shape, no markdown fences, no commentary:
      {
        "modules": ["key1", "key2"],
        "custom_modules": [
          { "label": "...", "description": "...", "impl_cost": 75000 }
        ],
        "industry": "Manufacturing",
        "company_size": "51-200",
        "pain_points": ["...", "..."]
      }

      If something cannot be inferred, omit the field (do not invent). Only include modules that
      genuinely fit the brief. Prefer the standard catalog wherever it covers the need.
    SYS
  end

  def build_user_content
    blocks = []

    if @file.present?
      file_block = encode_file(@file)
      return nil if file_block.nil?  # @error set by encode_file
      Array(file_block).each { |b| blocks << b }
    end

    if @text.present?
      blocks << { type: 'text', text: "Client requirements (pasted):\n#{@text[0, MAX_TEXT_CHARS]}" }
    elsif blocks.any?
      blocks << { type: 'text', text: "Analyse the attached and return the JSON described in the system prompt." }
    end

    blocks
  end

  def encode_file(file)
    size = file.respond_to?(:size) ? file.size : nil
    if size && size > MAX_FILE_BYTES
      @error = "File too large (max #{MAX_FILE_BYTES / 1_048_576} MB)."
      return nil
    end

    content_type = (file.respond_to?(:content_type) && file.content_type.to_s.downcase) || ''
    data = file.respond_to?(:read) ? file.read : File.read(file.to_s, mode: 'rb')

    if IMAGE_TYPES.key?(content_type)
      [{
        type: 'image',
        source: { type: 'base64', media_type: IMAGE_TYPES[content_type], data: Base64.strict_encode64(data) }
      }]
    elsif content_type == PDF_TYPE
      [{
        type: 'document',
        source: { type: 'base64', media_type: 'application/pdf', data: Base64.strict_encode64(data) }
      }]
    elsif content_type == DOCX_TYPE || file.respond_to?(:original_filename) && file.original_filename.to_s.downcase.end_with?('.docx')
      text = extract_docx_text(data)
      if text.blank?
        @error = 'Could not read .docx file.'
        return nil
      end
      [{ type: 'text', text: "Client requirements (from uploaded .docx):\n#{text[0, MAX_TEXT_CHARS]}" }]
    elsif TEXT_TYPES.include?(content_type)
      [{ type: 'text', text: "Client requirements (from uploaded text file):\n#{data.to_s[0, MAX_TEXT_CHARS]}" }]
    else
      @error = "Unsupported file type (#{content_type.presence || 'unknown'}). Use PDF, image, .docx, or text."
      nil
    end
  rescue => e
    Rails.logger.error("OdooProposalDetectionService.encode_file error: #{e.message}")
    @error = "Could not read file: #{e.message}"
    nil
  end

  def extract_docx_text(bytes)
    require 'docx'
    require 'stringio'
    doc = Docx::Document.open(StringIO.new(bytes))
    doc.paragraphs.map(&:text).reject(&:blank?).join("\n")
  rescue => e
    Rails.logger.error("docx parse error: #{e.message}")
    nil
  end

  def call_claude(user_content)
    uri = URI('https://api.anthropic.com/v1/messages')

    request = Net::HTTP::Post.new(uri)
    request['Content-Type']      = 'application/json'
    request['x-api-key']         = @api_key
    request['anthropic-version'] = '2023-06-01'

    request.body = {
      model: @model,
      max_tokens: 2500,
      system: system_prompt,
      messages: [{ role: 'user', content: user_content }]
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 120) do |http|
      http.request(request)
    end

    if response.code == '200'
      JSON.parse(response.body).dig('content', 0, 'text')
    else
      Rails.logger.error("Claude detection API error (#{response.code}): #{response.body}")
      @error = "AI service returned #{response.code}."
      nil
    end
  rescue => e
    Rails.logger.error("OdooProposalDetectionService error: #{e.message}")
    @error = "AI request failed: #{e.message}"
    nil
  end

  def parse_json(text)
    return nil if text.blank?
    json_match = text.match(/```json\s*(.*?)\s*```/m) || text.match(/\{.*\}/m)
    return nil unless json_match
    JSON.parse(json_match[1] || json_match[0])
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse detection JSON: #{e.message}\nResponse: #{text}")
    @error = "AI returned malformed JSON. Try again."
    nil
  end

  def normalise(parsed)
    valid_keys = OdooProposal::MODULES.values.flatten.map { |m| m[:key] }.to_set

    modules = Array(parsed['modules']).map(&:to_s).select { |k| valid_keys.include?(k) }.uniq

    custom_modules = Array(parsed['custom_modules']).filter_map do |m|
      next nil unless m.is_a?(Hash)
      label = m['label'].to_s.strip
      next nil if label.empty?
      {
        'label'       => label,
        'description' => m['description'].to_s.strip,
        'impl_cost'   => m['impl_cost'].to_i
      }
    end

    industry     = parsed['industry'].to_s.strip
    industry     = nil unless OdooProposal::INDUSTRIES.include?(industry)
    company_size = parsed['company_size'].to_s.strip
    company_size = nil unless OdooProposal::COMPANY_SIZES.map { |_, v| v }.include?(company_size)
    pain_points  = Array(parsed['pain_points']).map(&:to_s).map(&:strip)
                       .select { |p| OdooProposal::PAIN_POINTS.include?(p) }
                       .uniq

    {
      'modules'        => modules,
      'custom_modules' => custom_modules,
      'industry'       => industry,
      'company_size'   => company_size,
      'pain_points'    => pain_points
    }
  end
end
