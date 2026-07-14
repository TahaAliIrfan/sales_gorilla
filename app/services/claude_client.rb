require "net/http"
require "json"

# Thin Anthropic (Claude) client over Net::HTTP — no SDK gem. Two entry points:
#   .chat            plain conversational reply -> text
#   .chat_with_tools native Claude tool-use loop -> text (used by the admin assistant)
# Model ids: Haiku 4.5 for the cheap chatbots, Sonnet 4.6 where quality matters.
class ClaudeClient
  URL     = "https://api.anthropic.com/v1/messages".freeze
  VERSION = "2023-06-01".freeze
  HAIKU   = "claude-haiku-4-5-20251001".freeze
  SONNET  = "claude-sonnet-4-6".freeze

  class Error < StandardError; end

  def self.api_key
    Rails.application.credentials.dig(:anthropic, :api_key) ||
      Rails.application.credentials.dig(:ANTHROPIC_API_KEY) ||
      ENV["ANTHROPIC_API_KEY"]
  end

  def self.configured?
    api_key.present?
  end

  # messages: [{role:, content:}] (content may be a string or Anthropic block array).
  def self.chat(messages:, model:, system: nil, max_tokens: 1500)
    text_of(post(build(model:, messages:, system:, max_tokens:)))
  end

  # Native tool-use loop. tools: Anthropic-format tool defs. runner: ->(name, input_hash){ result }.
  # Returns the final text, or nil.
  def self.chat_with_tools(messages:, model:, tools:, runner:, system: nil, max_tokens: 1500, max_iters: 6)
    convo = normalize(messages)
    max_iters.times do
      resp   = post(build(model:, messages: convo, system:, max_tokens:).merge(tools: tools))
      blocks = Array(resp["content"])
      uses   = blocks.select { |b| b["type"] == "tool_use" }

      return text_of(resp) if uses.empty? || resp["stop_reason"] != "tool_use"

      convo << { role: "assistant", content: blocks }
      convo << { role: "user", content: uses.map { |tu|
        out = begin
          runner.call(tu["name"], tu["input"] || {})
        rescue => e
          Rails.logger.error("ClaudeClient tool #{tu["name"]} failed: #{e.message}")
          { error: e.message }
        end
        { type: "tool_result", tool_use_id: tu["id"], content: out.to_json }
      } }
    end
    nil
  end

  # ---- internals ----

  def self.build(model:, messages:, system:, max_tokens:)
    body = { model: model, max_tokens: max_tokens, messages: normalize(messages) }
    body[:system] = system if system.to_s.strip.present?
    body
  end

  def self.normalize(messages)
    Array(messages).filter_map do |m|
      role = (m[:role] || m["role"]).to_s == "assistant" ? "assistant" : "user"
      content = m[:content] || m["content"]
      next if content.nil? || (content.is_a?(String) && content.strip.empty?)
      { role: role, content: content }
    end
  end

  def self.text_of(resp)
    Array(resp["content"]).select { |b| b["type"] == "text" }.map { |b| b["text"] }.join("\n").presence
  end

  def self.post(body)
    key = api_key
    raise Error, "Anthropic API key not configured" if key.blank?

    uri = URI(URL)
    req = Net::HTTP::Post.new(uri)
    req["content-type"]      = "application/json"
    req["x-api-key"]         = key
    req["anthropic-version"] = VERSION
    req.body = body.to_json

    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 120) { |h| h.request(req) }
    raise Error, "Anthropic API error #{res.code}: #{res.body.to_s[0, 300]}" unless res.code == "200"
    JSON.parse(res.body)
  end
end
