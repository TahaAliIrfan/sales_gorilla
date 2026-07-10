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

  # ---- deterministic signals (0-70) ----

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

  # Deals: existence + pipeline progression + won + value (0-25)
  def deal_points
    deals = @customer.deals.to_a
    return 0 if deals.empty?

    pts = 8
    pts += 12 if deals.any? { |d| d.status == "won" }

    # furthest stage reached, relative to the pipeline length
    positions = deals.map { |d| d.deal_stage&.position }.compact
    if positions.any?
      max_pos = DealStage.maximum(:position).to_i
      pts += ((positions.max.to_f / [max_pos, 1].max) * 9).round if max_pos.positive?
    end

    top_amount = deals.map { |d| d.amount.to_f }.max
    pts += 8 if top_amount >= 20_000
    pts += 4 if top_amount.between?(5_000, 19_999.99)

    [pts, 25].min
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
    transcripts = call_transcripts

    <<~PROMPT
      You are qualifying a sales lead for a software development agency. Judge ONLY
      the lead's intent, seriousness and project value from their own words below.
      Do NOT consider name, ethnicity, gender or nationality.

      Return a JSON object (and nothing else):
      ```json
      { "quality_score": <integer 0-30>, "reason": "<one short sentence>" }
      ```

      Scoring guide (0-30):
      - 24-30: detailed, serious project with clear scope/budget and strong buying intent
      - 15-23: real project, moderate detail or intent
      - 7-14: vague or early-stage interest
      - 0-6: no real project, spam, or clearly not a fit

      PROJECT DESCRIPTION:
      #{@customer.idea_description.presence || "(none provided)"}

      RECENT MESSAGES:
      #{messages.presence || "(none)"}

      CALL NOTES/TRANSCRIPTS:
      #{transcripts.presence || "(none)"}
    PROMPT
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
