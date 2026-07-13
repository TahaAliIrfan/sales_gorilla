require "langchain"

# CRM-wide conversational assistant for admins. Unlike CustomerAiChatService
# (one customer stuffed into a prompt), this uses tool-calling: the model is
# given read-only tools and decides which to call to answer questions across the
# whole CRM ("which leads can I still reach out to?", "who mentioned budget on a
# call?", "won value by rep this month").
#
# Backed by OpenAI's gpt-5.5 via langchainrb's Assistant. Read-only: no tool
# writes to the database.
class AdminAssistantService
  MODEL       = "gpt-5.5"
  MAX_SECONDS = 120

  class MissingApiKey < StandardError; end
  # Surface rate limits distinctly so the UI can tell the admin to wait a moment
  # rather than showing a generic error.
  class RateLimited < StandardError; end

  def initialize(user)
    @user = user
  end

  # history: array of { "role" => "user"|"assistant", "content" => String },
  # ending with the new user message. Returns the assistant's reply text.
  def reply(history)
    api_key = openai_key
    raise MissingApiKey, "OPENAI_API_KEY is not configured" if api_key.blank?

    turns = sanitize(history)
    raise ArgumentError, "no messages" if turns.empty?

    run_with_retry(turns)
  end

  private

  def openai_key
    ENV["OPENAI_API_KEY"].presence || Rails.application.credentials.OPENAI_API_KEY
  end

  # One retry on a 429 rate limit, waiting the server-suggested delay. A fresh
  # assistant is built each attempt so a partial run doesn't leak into the retry.
  def run_with_retry(turns, attempts: 2)
    tries = 0
    begin
      tries += 1
      run_once(turns)
    rescue => e
      if rate_limited?(e)
        raise RateLimited, "Rate limit reached. Please wait a few seconds and try again." if tries >= attempts
        sleep(retry_after_seconds(e))
        retry
      end
      raise
    end
  end

  def run_once(turns)
    assistant = build_assistant(openai_key)

    # Seed the prior conversation, then run the newest user turn.
    prior, latest = turns[0..-2], turns[-1]
    prior.each { |t| assistant.add_message(role: t[:role], content: t[:content]) }

    Timeout.timeout(MAX_SECONDS) do
      assistant.add_message_and_run!(content: latest[:content])
    end

    reply = assistant.messages.reverse.find { |m| m.role == "assistant" && m.content.to_s.strip.present? }
    reply&.content.presence || "Sorry, I couldn't put together an answer just now. Please try again."
  end

  def rate_limited?(error)
    msg = error.message.to_s
    msg.include?("rate_limit") || msg.include?("Rate limit") || msg.include?("429")
  end

  # Parse the API's "try again in 3.51s" hint; fall back to a small fixed wait,
  # capped so we never block the request for long.
  def retry_after_seconds(error)
    seconds = error.message.to_s[/try again in ([\d.]+)s/, 1]&.to_f
    [[seconds || 3.0, 1.0].max, 8.0].min
  end

  private

  def build_assistant(api_key)
    # gpt-5.5 only accepts the default temperature (1.0); other values 400.
    llm = Langchain::LLM::OpenAI.new(
      api_key: api_key,
      default_options: { chat_model: MODEL, temperature: 1.0 }
    )

    Langchain::Assistant.new(
      llm: llm,
      instructions: system_prompt,
      tools: [AdminAssistant::CrmTools.new]
    )
  end

  def sanitize(history)
    Array(history).filter_map do |m|
      role = m["role"] || m[:role]
      text = (m["content"] || m[:content]).to_s.strip
      next unless %w[user assistant].include?(role) && text.present?
      { role: role, content: text[0, 8000] }
    end.last(20)
  end

  def system_prompt
    <<~PROMPT
      You are the admin analyst for a CRM used by a software development agency.
      You help #{@user&.name.presence || "an admin"} understand the whole book of
      business: leads, customers, deals, messages, and call transcripts.

      Today is #{Date.current.strftime('%A, %-d %B %Y')}.

      You have read-only tools. ALWAYS answer from tool results, never from
      memory or assumption. If you need data, call a tool. Chain tools when
      useful (e.g. list_stale_leads, then get_customer on the top few to explain
      why each is worth a call). If a tool returns nothing, say so plainly.

      Tools:
      - search_customers: find leads by name/company/status/country/rep.
      - get_customer: full record for one lead (profile, deals, messages, tasks).
      - list_stale_leads: leads still worth re-engaging (open, reachable, gone
        quiet). This is the go-to for "who can I still reach out to?".
      - search_transcripts: find leads by what was said on a call.
      - sales_summary: pipeline and won/lost rollups.

      When you surface leads, be specific and actionable: name them, give the one
      reason each is worth reaching out to (pulled from their record), and the
      best channel to use. Rank by likelihood of a reply where you can.

      Style: plain, short, direct. Use the lead's real details, not generic
      filler. Never use an em dash or en dash; use a comma or two sentences. No
      emojis, no marketing fluff. Prefer tight bullet lists over long paragraphs.
      When you reference a lead, include their name so the admin can find them.
    PROMPT
  end
end
