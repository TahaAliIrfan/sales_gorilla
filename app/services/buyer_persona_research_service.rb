class BuyerPersonaResearchService
  CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"
  CLAUDE_MODEL   = "claude-opus-4-7"

  def initialize(customer)
    @customer = customer
    @api_key  = Rails.application.credentials.dig(:anthropic, :api_key) || ENV['ANTHROPIC_API_KEY']
    raise "Anthropic API key not configured" unless @api_key
  end

  def research
    prompt   = build_prompt
    response = make_api_request(prompt)

    if response[:success]
      parse_response(response[:content])
    else
      { success: false, error: response[:error] }
    end
  rescue => e
    Rails.logger.error "BuyerPersonaResearchService error for customer #{@customer.id}: #{e.message}"
    { success: false, error: "Research service temporarily unavailable" }
  end

  private

  def build_prompt
    <<~PROMPT
      You are an expert sales intelligence analyst. A sales team has received a new lead and wants deep background research to personalize their outreach and understand how to best engage this prospect.

      ## Lead Information
      Name: #{@customer.name.presence || 'Unknown'}
      Email: #{@customer.email.presence || 'Not provided'}
      Company: #{@customer.company.presence || 'Unknown'}
      Country: #{@customer.country.presence || 'Unknown'}
      Project Description: #{@customer.idea_description.presence || 'Not provided'}
      Lead Source: #{@customer.lead_source.presence || 'Unknown'}
      Project Type: #{@customer.project_type.presence || 'Unknown'}

      ## Your Task
      Based on the email domain, company name, project description, and any other available signals, research and infer as much as possible about this lead. Use your knowledge of companies, industries, and professional backgrounds.

      Return ONLY a valid JSON object with this exact structure (no markdown, no extra text):
      {
        "professional_background": "Detailed analysis of the person's likely professional background based on email domain, company, and context. Include probable role, seniority, and career trajectory.",
        "industry_analysis": "Deep dive into their industry/sector — market dynamics, typical challenges, competitive landscape, technology adoption patterns, and budget cycles for this type of business.",
        "pain_points": "Most likely business pain points and frustrations this person faces based on their industry, company size, and project description. Be specific and actionable.",
        "budget_indicators": "Estimated budget range and financial indicators based on company size, industry, and project scope. Include decision-making authority signals.",
        "communication_style": "Recommended communication style — formal vs casual, technical depth, response timing expectations, preferred channels, and cultural considerations based on country/industry.",
        "recommended_approach": "Specific, actionable sales approach for this lead — what to lead with, what to avoid, key value propositions to emphasize, and suggested talking points.",
        "key_insights": "3-5 bullet points of the most important intelligence points that the sales rep must know before reaching out.",
        "persona_summary": "A 2-3 sentence executive summary of who this person is and the best way to win their business.",
        "confidence_score": 75
      }

      The confidence_score (0-100) reflects how much concrete data was available. Be honest — if only an email was provided, score lower (30-50). If company and description are rich, score higher (70-90).

      Research thoroughly. Be specific, not generic. If the email domain is a known company, use that knowledge. If the industry is identifiable, apply deep domain expertise.
    PROMPT
  end

  def make_api_request(prompt)
    uri  = URI(CLAUDE_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl     = true
    http.read_timeout = 90

    request = Net::HTTP::Post.new(uri)
    request['Content-Type']      = 'application/json'
    request['x-api-key']         = @api_key
    request['anthropic-version'] = '2023-06-01'

    request.body = {
      model:      CLAUDE_MODEL,
      max_tokens: 2000,
      messages:   [{ role: "user", content: prompt }]
    }.to_json

    response = http.request(request)

    if response.code == '200'
      result  = JSON.parse(response.body)
      content = result.dig('content', 0, 'text')
      { success: true, content: content }
    else
      error_msg = begin
        JSON.parse(response.body)['error']['message']
      rescue
        "API request failed with status #{response.code}"
      end
      { success: false, error: error_msg }
    end
  end

  def parse_response(content)
    json_match = content.match(/\{.*\}/m)
    return { success: false, error: "No valid JSON found in response" } unless json_match

    parsed = JSON.parse(json_match[0])

    {
      success:                 true,
      professional_background: parsed['professional_background'].to_s,
      industry_analysis:       parsed['industry_analysis'].to_s,
      pain_points:             parsed['pain_points'].to_s,
      budget_indicators:       parsed['budget_indicators'].to_s,
      communication_style:     parsed['communication_style'].to_s,
      recommended_approach:    parsed['recommended_approach'].to_s,
      key_insights:            parsed['key_insights'].to_s,
      persona_summary:         parsed['persona_summary'].to_s,
      confidence_score:        parsed['confidence_score'].to_i.clamp(0, 100),
      raw_response:            parsed
    }
  rescue JSON::ParserError => e
    { success: false, error: "Failed to parse research response: #{e.message}" }
  end
end
