require "httparty"

module Ai
  # Per-org wrapper over the Anthropic Messages API. Resolves the provider key
  # from the org's `ai` OrganizationFeature (bring-your-own-key), falling back to
  # a Tecaudex-wide default. Used by enrichment + call-script generation.
  class Client
    class MissingKey < StandardError; end
    class ApiError < StandardError; end

    ENDPOINT = "https://api.anthropic.com/v1/messages".freeze
    DEFAULT_MODEL = "claude-opus-4-8".freeze
    API_VERSION = "2023-06-01".freeze

    attr_reader :api_key, :model

    def self.for_organization(org)
      feature = org&.feature("ai")
      key   = feature&.settings_for("api_key").presence ||
              ENV["ANTHROPIC_API_KEY"].presence ||
              (Rails.application.credentials.dig(:anthropic_api_key) rescue nil)
      model = feature&.settings_for("model").presence || DEFAULT_MODEL
      new(api_key: key, model: model)
    end

    def initialize(api_key:, model: DEFAULT_MODEL)
      @api_key = api_key
      @model = model
    end

    def complete(system:, prompt:, max_tokens: 1500)
      post(model: @model, max_tokens: max_tokens, system: system,
           messages: [{ role: "user", content: prompt }])
    end

    def research(prompt:, max_tokens: 1500)
      post(model: @model, max_tokens: max_tokens,
           tools: [{ type: "web_search_20250305", name: "web_search", max_uses: 5 }],
           messages: [{ role: "user", content: prompt }])
    end

    private

    def post(body)
      raise MissingKey, "no AI api key configured" if @api_key.blank?
      resp = HTTParty.post(ENDPOINT,
        headers: {
          "x-api-key" => @api_key,
          "anthropic-version" => API_VERSION,
          "content-type" => "application/json"
        },
        body: body.to_json, timeout: 90)
      raise ApiError, "ai api #{resp.code}: #{resp.body.to_s[0, 200]}" unless resp.code == 200
      extract_text(resp.parsed_response)
    end

    def extract_text(data)
      Array(data && data["content"]).select { |b| b["type"] == "text" }.map { |b| b["text"] }.join("\n").strip
    end
  end
end
