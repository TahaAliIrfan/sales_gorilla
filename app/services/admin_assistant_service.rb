# CRM-wide conversational assistant for admins. Unlike CustomerAiChatService
# (one customer stuffed into a prompt), this uses tool-calling: the model is
# given read-only tools and decides which to call to answer questions across the
# whole CRM ("which leads can I still reach out to?", "who mentioned budget on a
# call?", "won value by rep this month").
#
# Backed by Claude Haiku (small + cheap) using native Claude tool-use, driven by
# ClaudeClient. The tool schemas + implementations live in AdminAssistant::CrmTools.
# Read-only: no tool writes to the database.
class AdminAssistantService
  MAX_TOKENS = 1500

  class MissingApiKey < StandardError; end

  def initialize(user)
    @user = user
  end

  # history: array of { "role" => "user"|"assistant", "content" => String },
  # ending with the new user message. Returns the assistant's reply text.
  def reply(history)
    raise MissingApiKey, "No AI provider is configured" unless ClaudeClient.configured?

    messages = sanitize(history)
    raise ArgumentError, "no messages" if messages.empty?

    crm = AdminAssistant::CrmTools.new
    runner = ->(name, input) do
      method = name.to_s.sub(/\Acrm__/, "")
      args = (input || {}).transform_keys(&:to_sym)
      crm.public_send(method, **args)
    end

    reply = ClaudeClient.chat_with_tools(
      system:   system_prompt,
      messages: messages,
      model:    ClaudeClient::HAIKU,
      tools:    AdminAssistant::CrmTools.function_schemas.to_anthropic_format,
      runner:   runner,
      max_tokens: MAX_TOKENS
    )
    reply.presence || "Sorry, I couldn't put together an answer just now. Please try again."
  end

  private

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
      - sales_summary: pipeline and won/lost rollups, for any period
        (this/last month, quarter, year, ytd) or an explicit start/end date
        range. It can cover any timeframe, so never say a period is unsupported.
      - rep_activity: per-rep call activity (total/successful call attempts,
        connect rate, leads never called, won deals). Use for "call attempts by
        rep" and rep performance.
      - lead_stats: count leads grouped by any field (status, lead_source,
        country, call/email/whatsapp status, lead_quality, customer_type,
        project_type, or rep), with optional filters and period. Use for any
        "how many leads by X" breakdown instead of eyeballing search results.

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
