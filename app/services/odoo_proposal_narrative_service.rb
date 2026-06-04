require "net/http"
require "json"

class OdooProposalNarrativeService
  SECTIONS = %w[summary rationale module_justifications next_steps].freeze

  attr_reader :proposal

  def initialize(proposal)
    @proposal = proposal
    @api_key = Rails.application.credentials.dig(:ANTHROPIC_API_KEY) || ENV["ANTHROPIC_API_KEY"]
    @model = "claude-sonnet-4-6"
  end

  def generate_all
    return nil if @api_key.blank?

    response = call_claude(build_full_prompt, max_tokens: 3500)
    parsed = parse_json(response)
    return nil unless parsed.is_a?(Hash)

    {
      "summary"               => parsed["summary"].to_s.strip,
      "rationale"             => parsed["rationale"].to_s.strip,
      "module_justifications" => (parsed["module_justifications"].is_a?(Hash) ? parsed["module_justifications"] : {}),
      "next_steps"            => parsed["next_steps"].to_s.strip
    }
  end

  def regenerate_section(section)
    return nil if @api_key.blank?
    section = section.to_s
    return nil unless SECTIONS.include?(section)

    response = call_claude(build_section_prompt(section), max_tokens: 1800)
    parsed = parse_json(response)
    return nil unless parsed.is_a?(Hash)

    if section == "module_justifications"
      parsed["module_justifications"].is_a?(Hash) ? parsed["module_justifications"] : nil
    else
      parsed[section].to_s.strip.presence
    end
  end

  private

  def proposal_context
    mods = @proposal.all_module_details
    modules_text = mods.map do |m|
      tag = m[:custom] ? " [CUSTOM DEV]" : ""
      "- #{m[:key]} | #{m[:label]}#{tag} | PKR #{m[:impl_cost]} | #{m[:description]}"
    end.join("\n")

    tier = @proposal.current_tier_info
    tier_text = tier ? "#{tier[:label]} — #{tier[:specs]}, suitable for #{tier[:users]}" : "Not applicable (Online deployment, managed by Odoo)"

    pain = @proposal.pain_points_array
    pain_text = pain.any? ? pain.join("; ") : "Not stated — infer reasonable enterprise pain points for this industry & size"

    <<~CTX
      ## Client Profile
      - Client name: #{@proposal.display_name}
      - Industry: #{@proposal.industry.presence || 'Not specified — infer from notes if possible'}
      - Company size: #{@proposal.company_size.presence || 'Not specified'}
      - Stated pain points: #{pain_text}
      - Notes from the sales team: #{@proposal.notes.presence || 'None'}

      ## Proposed Solution
      - Deployment: #{@proposal.deployment_label}
      - Hosting / platform tier: #{tier_text}
      - User count: #{@proposal.num_users}
      - Selected Odoo modules (#{mods.length}) — format is key | label | implementation fee | description:
      #{modules_text}

      ## Pricing (PKR)
      - One-time implementation fee: #{@proposal.implementation_fee.to_i}
      - Year 1 hosting: #{@proposal.hosting_yearly}
      - Annual Odoo subscription (#{@proposal.num_users} users): #{@proposal.subscription_yearly_total}
      - Year 1 total: #{@proposal.year_1_total}
      - Year 2+ recurring (annual): #{@proposal.year_2_recurring_yearly}
    CTX
  end

  def voice_instructions
    <<~VOICE
      You are a senior Odoo implementation consultant at Tecaudex (a Pakistan-based Official Odoo Partner) writing a client-facing proposal.

      Tone: professional, warm, confident, specific. Not pushy, not generic ERP-speak.
      You make the client feel understood and the recommendation feel inevitable.

      Hard rules:
      - Name the client by name at least once per long section. Reference their industry by name.
      - Tie every claim to a concrete detail from their profile (size, pain point, deployment choice, module choice).
      - Never use empty marketing words: "synergy", "leverage", "world-class", "best-in-class", "robust", "seamless".
      - Never start a sentence with "We" repeatedly. Vary openings.
      - Currency is PKR. Pakistan business context. Keep numbers when you cite them.
      - Write in clear English. No filler, no emoji, no markdown formatting in the output strings.
      - Output PLAIN TEXT inside JSON strings only. No bullets, no asterisks, no headings inside the strings.
    VOICE
  end

  def module_keys_list
    @proposal.all_module_details.map { |m| m[:key].to_s }
  end

  def build_full_prompt
    <<~PROMPT
      #{voice_instructions}

      #{proposal_context}

      Write four sections of the proposal narrative. Return STRICTLY VALID JSON only — no markdown fences, no commentary, no leading or trailing text.

      Required JSON shape:
      {
        "summary": "Executive summary, 3–5 sentences. Address the client's industry and pain points by name and frame this Odoo implementation as the natural solution. Reference their company size when relevant.",
        "rationale": "Why this specific configuration (modules + deployment + tier + user count) was recommended for THIS client. 4–6 sentences. Justify the deployment choice and tier specifically against their size and pain points.",
        "module_justifications": {
          #{module_keys_list.map { |k| "\"#{k}\": \"1–2 sentences on why this module specifically fits this client's situation.\"" }.join(",\n          ")}
        },
        "next_steps": "Customized next steps as a single string with each step on its own line separated by \\n. 4–6 steps. Tailor to their scale and selected modules — name specific workshops, migration tasks, training needs."
      }

      The module_justifications object MUST include an entry for every one of these keys exactly: #{module_keys_list.inspect}.
      Do not invent additional module keys.
    PROMPT
  end

  def build_section_prompt(section)
    instruction = case section
    when "summary"
      'Write ONLY the executive summary (3–5 sentences). Return JSON: { "summary": "..." }'
    when "rationale"
      'Write ONLY the recommendation rationale (4–6 sentences). Return JSON: { "rationale": "..." }'
    when "module_justifications"
      keys = module_keys_list
      "Write ONLY per-module justifications. Return JSON shaped like { \"module_justifications\": { #{keys.map { |k| "\"#{k}\": \"...\"" }.join(', ')} } }. Include an entry for every key exactly: #{keys.inspect}."
    when "next_steps"
      'Write ONLY the customised next steps (4–6 steps, each on its own line in a single string, \\n-separated). Return JSON: { "next_steps": "..." }'
    end

    <<~PROMPT
      #{voice_instructions}

      #{proposal_context}

      #{instruction}

      Return STRICTLY VALID JSON only — no markdown fences, no commentary.
    PROMPT
  end

  def call_claude(prompt, max_tokens:)
    uri = URI("https://api.anthropic.com/v1/messages")

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-api-key"] = @api_key
    request["anthropic-version"] = "2023-06-01"

    request.body = {
      model: @model,
      max_tokens: max_tokens,
      messages: [ { role: "user", content: prompt } ]
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 90) do |http|
      http.request(request)
    end

    if response.code == "200"
      JSON.parse(response.body).dig("content", 0, "text")
    else
      Rails.logger.error("Claude API error (#{response.code}): #{response.body}")
      nil
    end
  rescue => e
    Rails.logger.error("OdooProposalNarrativeService error: #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    nil
  end

  def parse_json(text)
    return nil if text.blank?

    json_match = text.match(/```json\s*(.*?)\s*```/m) || text.match(/\{.*\}/m)
    return nil unless json_match

    JSON.parse(json_match[1] || json_match[0])
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse Claude response: #{e.message}\nResponse: #{text}")
    nil
  end
end
