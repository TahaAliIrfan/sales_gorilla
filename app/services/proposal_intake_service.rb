require "openai"
require "json"

# Distills a Proposal Generator conversation into the structured inputs the
# estimate pipeline needs (a clean project description + platform/scale/design).
# Runs on gpt-5.5 with JSON output. Falls back to safe defaults if anything is
# unclear so "Generate proposal" always produces something.
class ProposalIntakeService
  OPENAI_MODEL = "gpt-5.5"

  APP_TYPES = %w[web mobile_ios mobile_android mobile_cross desktop ecommerce crm api custom].freeze
  SCALES    = %w[mvp moderate enterprise].freeze

  class MissingApiKey < StandardError; end

  def initialize(user: nil)
    @user = user
  end

  # history: [{role, content}, ...]. Returns a hash with symbol keys:
  # { description:, app_type:, scale:, include_design:, project_name:, customer_name: }
  def extract(history)
    api_key = ENV["OPENAI_API_KEY"].presence || Rails.application.credentials.OPENAI_API_KEY
    raise MissingApiKey, "OPENAI_API_KEY is not configured" if api_key.blank?

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

  def prompt(transcript)
    <<~PROMPT
      From the conversation below between a sales rep and an assistant scoping a
      software project, extract the inputs needed to build a cost estimate.

      Return ONLY this JSON, nothing else:
      {
        "description": "a clear, self-contained paragraph describing the project, its purpose, and the main features discussed",
        "app_type": one of #{APP_TYPES.inspect},
        "scale": one of #{SCALES.inspect},
        "include_design": true or false,
        "project_name": "a short product name if one was mentioned, else empty string",
        "customer_name": "the client/company name if mentioned, else empty string"
      }

      Rules:
      - "description" must stand on its own (do not reference "the conversation").
      - Pick app_type from the platform discussed; use "web" if a website/web app,
        "mobile_cross" for a cross-platform mobile app, "custom" if unclear.
      - scale: "mvp" for a lean first version, "moderate" for a standard build,
        "enterprise" for large/complex; default "moderate" if unclear.
      - include_design: true unless the rep said design is not needed.

      CONVERSATION:
      #{transcript}
    PROMPT
  end

  def parse(content)
    json = content.to_s[/\{.*\}/m]
    data = json ? JSON.parse(json) : {}
    {
      description: data["description"].to_s.strip,
      app_type: APP_TYPES.include?(data["app_type"]) ? data["app_type"] : "custom",
      scale: SCALES.include?(data["scale"]) ? data["scale"] : "moderate",
      include_design: data.fetch("include_design", true) ? true : false,
      project_name: data["project_name"].to_s.strip,
      customer_name: data["customer_name"].to_s.strip
    }
  rescue JSON::ParserError => e
    Rails.logger.error("ProposalIntakeService parse error: #{e.message}")
    { description: "", app_type: "custom", scale: "moderate", include_design: true, project_name: "", customer_name: "" }
  end
end
