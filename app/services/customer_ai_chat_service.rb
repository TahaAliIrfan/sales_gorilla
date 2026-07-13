require "net/http"
require "json"

# Conversational AI assistant scoped to a single customer. The rep asks
# questions ("what's the state of this lead?", "draft a follow-up email",
# "what should I say on the next call?") and Claude answers with the full
# CRM context for that customer stitched into a system prompt.
#
# Stateless: the browser holds the running conversation and posts the whole
# history back each turn (see ai_chat_controller.js). We rebuild the customer
# context fresh on every call so answers reflect the latest CRM state.
class CustomerAiChatService
  CLAUDE_API_URL    = "https://api.anthropic.com/v1/messages"
  CLAUDE_MODEL      = "claude-sonnet-4-6"
  ANTHROPIC_VERSION = "2023-06-01"
  MAX_TOKENS        = 1024

  class MissingApiKey < StandardError; end

  def initialize(customer, user: nil)
    @customer = customer
    @user = user
  end

  # history: array of { "role" => "user"|"assistant", "content" => String }.
  # Returns the assistant's reply text, or raises on transport/config errors.
  def reply(history)
    api_key = ENV["ANTHROPIC_API_KEY"] || Rails.application.credentials.dig(:anthropic, :api_key)
    raise MissingApiKey, "ANTHROPIC_API_KEY is not configured" if api_key.blank?

    messages = sanitize(history)
    raise ArgumentError, "no messages" if messages.empty?

    content = claude(messages, api_key)
    content.presence || "Sorry, I couldn't generate a response just now. Please try again."
  end

  private

  # Keep only well-formed user/assistant turns with non-blank content, and cap
  # the length so a runaway history can't blow past the model's context window.
  def sanitize(history)
    Array(history).filter_map do |m|
      role = m["role"] || m[:role]
      text = (m["content"] || m[:content]).to_s.strip
      next unless %w[user assistant].include?(role) && text.present?
      { role: role, content: text[0, 8000] }
    end.last(30)
  end

  def system_prompt
    <<~PROMPT
      You are an AI sales assistant embedded in a CRM for a software development
      agency. You are helping #{@user&.name.presence || "a sales rep"} move a
      specific customer/lead forward. Work only from the context below plus what
      the rep tells you; if something isn't there, say so rather than inventing
      it.

      Figure out which of these jobs the rep is asking for and do that one — do
      not pad the answer with the others:

      1. PREP A CALL — a 30-second brief: who they are and where the deal stands,
         the last thing that happened, one goal for the call, and 2–3 questions
         to ask. Mention the best time to reach them (respect their timezone and
         preferred calling time).
      2. DRAFT OUTREACH / FOLLOW-UP — write it ready to send. Match the channel:
         email is brief and specific; WhatsApp is short and casual; LinkedIn is
         warm with no hard pitch. Reference something real from their record so
         it doesn't read like a template. Make one clear ask, not three.
      3. QUALIFY A LEAD — state the lead score and the honest reason, call fit vs
         no-fit plainly, and recommend keep / nurture / drop with a one-line why.
      4. NEXT BEST ACTION — one concrete step, who does it, and by when.

      Send rules: WhatsApp only sends freely inside a 24-hour window (templates
      otherwise), and marketing templates to US/Canada (+1) numbers are blocked.
      If a message the rep wants would bounce, tell them.

      Style: plain and short. No emojis, no big markdown headers, no "think of it
      as N layers" framing. Give the thing the rep will actually send or read,
      then stop.

      ===== CUSTOMER CONTEXT =====
      #{customer_context}
      ============================
    PROMPT
  end

  def customer_context
    sections = []
    sections << profile_section
    sections << "LEAD SCORE: #{@customer.lead_score} — #{@customer.lead_score_reason}" if @customer.lead_score.present?
    sections << "PROJECT DESCRIPTION:\n#{@customer.idea_description}" if @customer.idea_description.present?
    sections << "REP NOTES:\n#{notes}" if notes.present?
    sections << "DEALS:\n#{deals}" if deals.present?
    sections << "OPEN TASKS:\n#{tasks}" if tasks.present?
    sections << "RECENT ACTIVITY:\n#{activities}" if activities.present?
    sections << "WHATSAPP / MESSAGES:\n#{messages}" if messages.present?
    sections << "RECENT EMAILS:\n#{emails}" if emails.present?
    sections << "CALL TRANSCRIPTS:\n#{transcripts}" if transcripts.present?
    sections.join("\n\n")
  end

  def profile_section
    <<~PROFILE.strip
      Name: #{@customer.name}
      Company: #{@customer.company.presence || "(unknown)"}
      Email: #{@customer.email.presence || "(none)"}
      Phone: #{@customer.phone.presence || "(none)"}
      Country: #{@customer.country.presence || "(unknown)"}
      Status: #{@customer.status.presence || "(none)"}
      Lead source: #{@customer.lead_source.presence || "(unknown)"}
      Assigned rep: #{@customer.user&.name.presence || "(unassigned)"}
      Timezone: #{timezone_label}
      Preferred calling time: #{@customer.preferred_calling_time.presence || "(unknown)"}
      Calls: #{@customer.successful_call_attempts.to_i} connected of #{@customer.total_call_attempts.to_i} attempts
    PROFILE
  end

  # Their timezone plus current local time, so the model can suggest when to
  # call. Guarded — location/timezone may be missing.
  def timezone_label
    tz = @customer.customer_location&.timezone
    return "(unknown)" if tz.blank?
    now = @customer.current_time_in_timezone rescue nil
    now ? "#{tz} (now #{now.strftime('%a %-l:%M %p')} their time)" : tz
  rescue
    "(unknown)"
  end

  def notes
    [@customer.notes.presence, @customer.followup_notes.presence].compact.join("\n")
  end

  def deals
    @customer.deals.order(created_at: :desc).limit(10).filter_map do |d|
      stage = d.deal_stage&.name rescue nil
      amount = d.amount.present? ? " — $#{d.amount.to_i}" : ""
      "• #{d.try(:name).presence || "Deal ##{d.id}"} (#{d.status}#{stage ? ", #{stage}" : ""})#{amount}"
    end.join("\n")
  rescue
    nil
  end

  def tasks
    @customer.tasks.where.not(status: "completed").order(due_date: :asc).limit(10).filter_map do |t|
      due = t.due_date.present? ? " (due #{t.due_date.to_date})" : ""
      "• #{t.try(:title).presence || t.try(:name).presence || "Task ##{t.id}"}#{due}"
    end.join("\n")
  rescue
    nil
  end

  def activities
    @customer.customer_activities.order(created_at: :desc).limit(10).filter_map do |a|
      text = a.try(:description).presence || a.try(:activity_type).presence
      next if text.blank?
      "• #{a.created_at.to_date}: #{text}"
    end.join("\n")
  rescue
    nil
  end

  def messages
    @customer.messages.order(created_at: :desc).limit(15)
             .map { |m| "#{m.direction}: #{m.content}" }.reverse.join("\n")
  rescue
    nil
  end

  def emails
    return nil unless @customer.respond_to?(:emails)
    @customer.emails.order(created_at: :desc).limit(5).filter_map do |e|
      subject = e.try(:subject)
      body = e.try(:snippet) || e.try(:body_plain) || e.try(:body)
      next if subject.blank? && body.blank?
      "#{subject} — #{body.to_s.gsub(/\s+/, ' ').strip[0, 300]}".strip
    end.join("\n---\n")
  rescue
    nil
  end

  def transcripts
    @customer.recordings.order(created_at: :desc).limit(5).filter_map do |r|
      r.transcription if r.respond_to?(:transcription) && r.transcription.present?
    end.join("\n---\n")
  rescue
    nil
  end

  def claude(messages, api_key)
    uri = URI.parse(CLAUDE_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri.path)
    request["content-type"]      = "application/json"
    request["x-api-key"]         = api_key
    request["anthropic-version"] = ANTHROPIC_VERSION
    request.body = {
      model: CLAUDE_MODEL,
      max_tokens: MAX_TOKENS,
      system: system_prompt,
      messages: messages
    }.to_json

    response = http.request(request)
    if response.code == "200"
      JSON.parse(response.body).dig("content", 0, "text")
    else
      Rails.logger.error("CustomerAiChatService Claude API error: #{response.code} - #{response.body}")
      raise "Claude API error (#{response.code})"
    end
  end
end
