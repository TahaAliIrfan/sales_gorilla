require "net/http"
require "json"

# Lead scoring — a transparent 0-100 score combining deterministic CRM signals
# (always available, updates as calls/deals progress) with an optional Claude AI
# quality read of the lead's own words (description + recent messages + call
# transcripts). No name/ethnicity heuristics.
#
#   rules (0-70)  +  AI quality (0-30)  =  lead_score (0-100)
#
# Use `run_ai: false` for the cheap live recompute triggered by call/deal events;
# `run_ai: true` (default) re-reads the qualitative signal and caches it.
class LeadScoringService
  CLAUDE_API_URL   = "https://api.anthropic.com/v1/messages"
  CLAUDE_MODEL     = "claude-sonnet-4-6"
  ANTHROPIC_VERSION = "2023-06-01"

  def initialize(customer)
    @customer = customer
  end

  def refresh!(run_ai: true)
    quality = if run_ai
                ai_quality # {score:, reason:} or nil
              else
                { score: @customer.description_score || 0, reason: @customer.lead_score_reason }
              end

    quality ||= { score: @customer.description_score || 0, reason: @customer.lead_score_reason }

    total = (rule_score + quality[:score].to_i).clamp(0, 100)

    @customer.update_columns(
      lead_score: total,
      description_score: quality[:score].to_i,
      lead_score_reason: quality[:reason],
      lead_score_updated_at: Time.current
    )
    total
  end

  # ---- deterministic signals (clamped with AI to 0-100) ----

  def rule_score
    status_points + call_points + deal_points + message_points
  end

  # Pipeline status (0-20)
  def status_points
    case @customer.status
    when "Converted" then 20
    when "Proposal Sent" then 16
    when "Contact Established" then 10
    when "Lead" then 8
    when "Pending" then 4
    else 0
    end
  end

  # Connected calls (0-20) — connecting with a lead is a strong signal.
  def call_points
    [(@customer.successful_call_attempts.to_i * 8) + [@customer.total_call_attempts.to_i, 2].min, 20].min
  end

  # Deals & pipeline stage (0-30). Having a deal is a strong signal; how far it
  # has advanced through its pipeline scales it up, and a won deal maxes it out.
  def deal_points
    deals = @customer.deals.to_a
    return 0 if deals.empty?
    return 30 if deals.any? { |d| d.status == "won" }

    pts = 10 # has an active deal in play

    # Deepest stage reached, measured against that deal's own pipeline length.
    pts += (best_stage_fraction(deals) * 15).round

    # A sizeable open deal adds a little more.
    pts += 5 if deals.map { |d| d.amount.to_f }.max >= 20_000

    [pts, 30].min
  end

  # How far (0.0–1.0) the furthest-advanced deal has moved through its pipeline.
  def best_stage_fraction(deals)
    fractions = deals.filter_map do |deal|
      stage = deal.deal_stage
      next unless stage&.position
      pipeline_max = DealStage.where(pipeline_id: stage.pipeline_id).maximum(:position).to_i
      pipeline_max.positive? ? (stage.position.to_f / pipeline_max) : 0.0
    end
    fractions.max || 0.0
  rescue
    0.0
  end

  # Two-way messaging (0-5) — the lead replied.
  def message_points
    @customer.messages.where(direction: "inbound").exists? ? 5 : 0
  end

  # ---- AI qualitative read (0-30) ----

  def ai_quality
    api_key = ENV["ANTHROPIC_API_KEY"] || Rails.application.credentials.dig(:anthropic, :api_key)
    return nil if api_key.blank?

    prompt = build_prompt
    content = claude(prompt, api_key)
    return nil unless content

    json = extract_json(content)
    return nil unless json

    { score: json["quality_score"].to_i.clamp(0, 30), reason: json["reason"].to_s.strip.presence }
  rescue => e
    Rails.logger.error("LeadScoringService AI error: #{e.message}")
    nil
  end

  private

  def build_prompt
    messages = @customer.messages.order(created_at: :desc).limit(12)
                        .map { |m| "#{m.direction}: #{m.content}" }.reverse.join("\n")
    notes = [@customer.notes.presence, @customer.followup_notes.presence].compact.join("\n")
    emails = email_snippets
    transcripts = call_transcripts

    <<~PROMPT
      You are qualifying an inbound sales lead for a software development agency.
      Score how strong and serious this lead is based on the QUALITY & CLARITY of
      what they want built and how ENGAGED they are across channels (project
      description, call notes/transcripts, WhatsApp messages, emails, rep notes).

      IMPORTANT: leads almost never mention a budget, timeline or price — do NOT
      expect them and do NOT lower the score for their absence. Focus on the
      substance of the project and the depth of the conversation instead. Ignore
      name, ethnicity, gender and nationality.

      Weigh:
      - Project description — clear, specific, a real buildable product vs. vague,
        one-line, or spam.
      - Engagement — genuine two-way conversation, thoughtful replies, questions,
        booked calls/meetings across WhatsApp/email/calls/notes.
      - Fit — a legitimate software project an agency could take on.

      Return ONLY this JSON:
      ```json
      { "quality_score": <integer 0-30>, "reason": "<one short sentence>" }
      ```

      Guide: 24-30 = clear, specific project with strong engagement; 15-23 = real
      project with some detail or interaction; 7-14 = vague or early interest;
      0-6 = no real project, spam, or not a fit.

      PROJECT DESCRIPTION:
      #{@customer.idea_description.presence || "(none provided)"}

      REP NOTES:
      #{notes.presence || "(none)"}

      WHATSAPP / MESSAGES:
      #{messages.presence || "(none)"}

      EMAILS:
      #{emails.presence || "(none)"}

      CALL NOTES / TRANSCRIPTS:
      #{transcripts.presence || "(none)"}
    PROMPT
  end

  # Best-effort recent email context (subject + snippet), guarded against schema
  # differences.
  def email_snippets
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

  # Best-effort call transcripts — only if the recording model exposes them.
  def call_transcripts
    @customer.recordings.order(created_at: :desc).limit(5).filter_map do |r|
      r.transcription if r.respond_to?(:transcription) && r.transcription.present?
    end.join("\n---\n")
  rescue
    nil
  end

  def claude(prompt, api_key)
    uri = URI.parse(CLAUDE_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path)
    request["content-type"]     = "application/json"
    request["x-api-key"]        = api_key
    request["anthropic-version"] = ANTHROPIC_VERSION
    request.body = {
      model: CLAUDE_MODEL,
      max_tokens: 400,
      messages: [{ role: "user", content: prompt }]
    }.to_json

    response = http.request(request)
    if response.code == "200"
      JSON.parse(response.body).dig("content", 0, "text")
    else
      Rails.logger.error("Claude lead-score API error: #{response.code} - #{response.body}")
      nil
    end
  end

  def extract_json(text)
    fenced = text[/```json\s*\n(.*?)\n```/m, 1]
    JSON.parse(fenced || text[/\{.*\}/m])
  rescue JSON::ParserError
    nil
  end
end
