# Conversational AI assistant scoped to a single customer. The rep asks
# questions ("what's the state of this lead?", "draft a follow-up email",
# "what should I say on the next call?") and the model answers with the full
# CRM context for that customer stitched into a system prompt.
#
# Backed by Claude Haiku (a small, cheap model) — this is a high-frequency
# chatbot, so cost matters. Stateless: the browser holds the running
# conversation and posts the whole history back each turn (see
# ai_chat_controller.js). We rebuild the customer context fresh on every call so
# answers reflect the latest CRM state.
class CustomerAiChatService
  MAX_TOKENS = 1500

  class MissingApiKey < StandardError; end

  def initialize(customer, user: nil)
    @customer = customer
    @user = user
  end

  # history: array of { "role" => "user"|"assistant", "content" => String }.
  # Returns the assistant's reply text, or raises on transport/config errors.
  def reply(history)
    raise MissingApiKey, "No AI provider is configured" unless ClaudeClient.configured?

    messages = sanitize(history)
    raise ArgumentError, "no messages" if messages.empty?

    content = ClaudeClient.chat(system: system_prompt, messages: messages, model: ClaudeClient::HAIKU, max_tokens: MAX_TOKENS)
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

      Before you draft anything, read the whole record below: the profile, the
      project description, the deals and their stage, the notes, and every
      message, email, and call in the history. Ground the draft in the specifics
      of that history. Pick up where the last conversation left off, reference
      what they actually said and what they want built, and match how this person
      already talks to us. Never send a generic template.

      Figure out which of these jobs the rep is asking for and do that one. Do
      not pad the answer with the others:

      1. PREP A CALL: a 30-second brief covering who they are and where the deal
         stands, the last thing that happened, one goal for the call, and 2 or 3
         questions to ask. Mention the best time to reach them (respect their
         timezone and preferred calling time).
      2. DRAFT OUTREACH / FOLLOW-UP: write it ready to send. Match the channel.
         Email is brief and specific. WhatsApp is short and casual. LinkedIn is
         warm with no hard pitch. Reference something real from their record so
         it does not read like a template. Make one clear ask, not three.
      3. WRITE A SALES PITCH: a short, specific pitch tied to what this customer
         actually needs, based on their record. Lead with the problem you solve
         for them, not a feature list. One clear next step at the end.
      4. QUALIFY A LEAD: state the lead score and the honest reason, call fit vs
         no-fit plainly, and recommend keep, nurture, or drop with a one-line why.
      5. NEXT BEST ACTION: one concrete step, who does it, and by when.

      Send rules: WhatsApp only sends freely inside a 24-hour window (templates
      otherwise), and marketing templates to US/Canada (+1) numbers are blocked.
      If a message the rep wants would bounce, tell them.

      Style: plain, short, and human. Write the way a real person actually texts
      or emails a client, not the way an AI writes. Use contractions. Keep
      sentences short. NEVER use an em dash or en dash (the "—" or "–" character);
      use a comma, a period, or two separate sentences instead. Skip stock AI
      filler like "I hope this email finds you well", "I wanted to reach out",
      "delve", "leverage", "streamline", "in today's fast-paced world". No emojis,
      no markdown headers. When you draft a message to the customer, give only the
      message the rep will send, then stop. For an email, make the very first line
      "Subject: ..." followed by a blank line and then the body, so it can be sent
      as-is.

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
    sections << "WHATSAPP / TEXT HISTORY (Them = the customer, Us = us):\n#{messages}" if messages.present?
    sections << "EMAIL HISTORY (Them = the customer, Us = us):\n#{emails}" if emails.present?
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
      LinkedIn: #{@customer.linkedin_url.presence || "(none)"}
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

  # Both WhatsApp/text channels merged into one chronological thread: the
  # green-api "messages" table and the Twilio "whatsapp_messages" table.
  # Labelled Them (the customer) vs Us (the rep) so the model can read the flow.
  def messages
    turns = []
    @customer.messages.order(created_at: :desc).limit(25).each do |m|
      turns << { at: m.created_at, dir: m.direction, text: m.content }
    end
    if @customer.respond_to?(:whatsapp_messages)
      @customer.whatsapp_messages.order(created_at: :desc).limit(25).each do |m|
        turns << { at: m.created_at, dir: m.direction, text: m.body }
      end
    end

    turns.reject! { |t| t[:text].to_s.strip.blank? }
    return nil if turns.empty?

    turns.sort_by { |t| t[:at] || Time.at(0) }.last(40).map do |t|
      who = t[:dir].to_s == "inbound" ? "Them" : "Us"
      "#{who}: #{t[:text].to_s.strip}"
    end.join("\n")
  rescue
    nil
  end

  def emails
    return nil unless @customer.respond_to?(:emails)
    @customer.emails.order(created_at: :desc).limit(10).filter_map do |e|
      subject = e.try(:subject)
      body = e.try(:snippet).presence || e.try(:body_text).presence || e.try(:body_html)
      next if subject.blank? && body.blank?
      who = e.try(:from_email).to_s.casecmp?(@customer.email.to_s) ? "Them" : "Us"
      clean = body.to_s.gsub(/<[^>]+>/, " ").gsub(/\s+/, " ").strip[0, 400]
      "#{who} | #{subject.to_s.strip}: #{clean}".strip
    end.reverse.join("\n---\n")
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
end
