require "openai"
require "json"

# Distills an Odoo proposal chat into a structured spec (Odoo modules to
# implement, deployment, users, industry) so the chat can build a real
# OdooProposal. gpt-5.5 with JSON output; grounded in the actual module
# catalogue so it can only pick valid module keys. Safe defaults on anything
# unclear so "Generate proposal" always produces something.
class OdooProposalIntakeService
  OPENAI_MODEL = "gpt-5.5"
  VALID_KEYS = OdooProposal::MODULES.values.flatten.map { |m| m[:key] }.freeze
  DEPLOYMENTS = %w[online sh on_premise].freeze

  def initialize(user: nil)
    @user = user
  end

  # history: [{role, content}, ...]. Returns a symbol-keyed spec hash.
  def extract(history)
    api_key = ENV["OPENAI_API_KEY"].presence || Rails.application.credentials.OPENAI_API_KEY
    raise "OPENAI_API_KEY is not configured" if api_key.blank?

    transcript = Array(history).filter_map do |m|
      role = m["role"] || m[:role]
      text = (m["content"] || m[:content]).to_s.strip
      next if text.blank? || !%w[user assistant].include?(role)
      "#{role.upcase}: #{text}"
    end.join("\n\n")

    client = OpenAI::Client.new(access_token: api_key, request_timeout: 90)
    response = client.chat(parameters: {
      model: OPENAI_MODEL,
      messages: [{ role: "user", content: prompt(transcript) }],
      max_completion_tokens: 4000,
      reasoning_effort: "low"
    })
    parse(response.dig("choices", 0, "message", "content"))
  end

  private

  def catalogue
    OdooProposal::MODULES.map do |category, mods|
      list = mods.map { |m| "#{m[:key]} (#{m[:label]})" }.join(", ")
      "#{category}: #{list}"
    end.join("\n")
  end

  def prompt(transcript)
    <<~PROMPT
      From the conversation below between a rep and an assistant scoping an Odoo
      ERP implementation, extract a structured spec.

      Choose Odoo modules ONLY from this catalogue (use the exact keys shown):
      #{catalogue}

      Return ONLY this JSON, nothing else:
      {
        "selected_modules": ["module_key", ...],
        "custom_modules": [{"name": "short name", "cost": <PKR integer or 0>}],
        "deployment_type": one of #{DEPLOYMENTS.inspect},
        "num_users": <integer>,
        "industry": "the client's industry if mentioned, else empty string",
        "company_size": "e.g. '20 employees' if mentioned, else empty string",
        "pain_points": "one or two sentences on what they're trying to fix",
        "customer_name": "client/company name if mentioned, else empty string"
      }

      Rules:
      - selected_modules: pick the modules that fit the needs discussed; keys MUST
        be from the catalogue. Include at least one.
      - custom_modules: only bespoke needs not covered by a standard module.
      - deployment_type: default "online" (Odoo's cloud) unless self-hosting or
        on-premise is clearly indicated.
      - num_users: default 10 if unclear.

      CONVERSATION:
      #{transcript}
    PROMPT
  end

  def parse(content)
    data = JSON.parse(content.to_s[/\{.*\}/m].to_s) rescue {}
    data = {} unless data.is_a?(Hash)

    keys = Array(data["selected_modules"]).map(&:to_s) & VALID_KEYS
    customs = Array(data["custom_modules"]).filter_map do |c|
      next unless c.is_a?(Hash) && c["name"].to_s.strip.present?
      { "name" => c["name"].to_s.strip, "cost" => c["cost"].to_i }
    end

    {
      selected_modules: keys,
      custom_modules: customs,
      deployment_type: DEPLOYMENTS.include?(data["deployment_type"]) ? data["deployment_type"] : "online",
      num_users: (data["num_users"].to_i > 0 ? data["num_users"].to_i : 10),
      industry: data["industry"].to_s.strip,
      company_size: data["company_size"].to_s.strip,
      pain_points: data["pain_points"].to_s.strip,
      customer_name: data["customer_name"].to_s.strip
    }
  rescue => e
    Rails.logger.error("OdooProposalIntakeService parse error: #{e.message}")
    { selected_modules: [], custom_modules: [], deployment_type: "online", num_users: 10,
      industry: "", company_size: "", pain_points: "", customer_name: "" }
  end
end
