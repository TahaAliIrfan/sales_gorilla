require "openai"

# Conversational front-end for the Proposal Generator. The rep describes (or
# uploads) a project; this assistant talks it through like a normal AI, asks the
# few things it needs to size the work, and tells the rep when there's enough to
# generate the proposal. It does NOT build the proposal itself — that's a
# separate step (ProposalIntakeService + the estimate/narrative/PDF pipeline).
#
# Stateless: the browser holds the running conversation and posts it back each
# turn (see proposal_chat_controller.js). Uploaded-file text is folded into the
# user turn by the controller before it reaches here.
class ProposalChatService
  OPENAI_MODEL          = "gpt-5.5"
  MAX_COMPLETION_TOKENS = 3000

  class MissingApiKey < StandardError; end

  def initialize(user: nil)
    @user = user
  end

  def reply(history)
    api_key = ENV["OPENAI_API_KEY"].presence || Rails.application.credentials.OPENAI_API_KEY
    raise MissingApiKey, "OPENAI_API_KEY is not configured" if api_key.blank?

    messages = sanitize(history)
    raise ArgumentError, "no messages" if messages.empty?

    client = OpenAI::Client.new(access_token: api_key, request_timeout: 90)
    response = client.chat(parameters: {
      model: OPENAI_MODEL,
      messages: [{ role: "system", content: system_prompt }] + messages,
      max_completion_tokens: MAX_COMPLETION_TOKENS,
      reasoning_effort: "low"
    })
    content = response.dig("choices", 0, "message", "content")
    content.presence || "Sorry, I couldn't respond just now. Please try again."
  rescue Faraday::Error => e
    body = (e.response&.dig(:body) rescue nil)
    Rails.logger.error("ProposalChatService OpenAI error: #{e.message} - #{body}")
    raise "OpenAI API error"
  end

  private

  def sanitize(history)
    Array(history).filter_map do |m|
      role = m["role"] || m[:role]
      text = (m["content"] || m[:content]).to_s.strip
      next unless %w[user assistant].include?(role) && text.present?
      { role: role, content: text[0, 12000] }
    end.last(30)
  end

  def system_prompt
    <<~PROMPT
      You are a friendly solutions consultant at a software development agency,
      helping #{@user&.name.presence || "a sales rep"} scope a client's project
      so we can generate a proposal for it.

      Talk like a normal, helpful assistant. Your job in the conversation is to
      understand the project well enough to size it:
      - What they want to build and the core features / goals.
      - The platform (web app, mobile app, both, etc.).
      - Rough scale: a lean MVP, a moderate build, or a large/enterprise system.
      - Whether UI/UX design is included.
      If the rep pastes or uploads requirements, read them and work from that.

      Ask only for what's missing, one or two questions at a time, and infer
      sensible defaults rather than interrogating. Keep replies short and plain.
      Never use an em dash or en dash; use a comma or two sentences. No emojis.

      When you have a clear picture of the project and its scale, briefly
      summarise what you understood (product, key features, platform, scale,
      design yes/no) and tell the rep they can click "Generate proposal" to
      produce the full costed proposal PDF. Do not try to write the cost estimate
      or the proposal yourself; the Generate step does that.
    PROMPT
  end
end
