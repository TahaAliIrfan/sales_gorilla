require 'net/http'
require 'json'

class CostEstimateAiService
  attr_reader :api_key, :model

  def initialize
    @api_key = Rails.application.credentials.dig(:ANTHROPIC_API_KEY) || ENV['ANTHROPIC_API_KEY']
    @model = "claude-sonnet-4-20250514"

    if @api_key.blank?
      Rails.logger.error("Anthropic API key is not configured")
    end
  end

  def generate_project_analysis(cost_estimate)
    return nil if @api_key.blank?

    prompt = build_analysis_prompt(cost_estimate)
    response = analyze_with_claude(prompt)

    if response
      parse_analysis_response(response)
    else
      nil
    end
  end

  def generate_mockups_html(cost_estimate, app_name)
    return nil if @api_key.blank?

    app_types = cost_estimate.application_types_array
    return nil if app_types.empty?

    # Determine if we need web or mobile mockups
    needs_web = app_types.any? { |type| type.downcase.include?('web') }
    needs_mobile = app_types.any? { |type| type.downcase.include?('mobile') || type.downcase.include?('ios') || type.downcase.include?('android') }

    mockups_html = ""

    if needs_web
      mockups_html += generate_web_mockup_html(cost_estimate, app_name)
    end

    if needs_mobile
      mockups_html += generate_mobile_mockup_html(cost_estimate, app_name)
    end

    mockups_html
  end

  private

  def build_analysis_prompt(cost_estimate)
    app_types = cost_estimate.application_types_array.join(", ")
    features = cost_estimate.proposed_features_array.presence || cost_estimate.features
    features_text = features.map { |f| f['name'] || f[:name] }.join(", ")

    <<~PROMPT
      You are an enthusiastic business development consultant and technical product analyst with a passion for encouraging innovation. Your goal is to make clients EXCITED about building their product by highlighting opportunities, market potential, and the value of their vision.

      IMPORTANT: Be ENCOURAGING and POSITIVE. Focus on opportunities, potential, and why this is a great project to build. Never discourage or highlight excessive risks. Your tone should inspire confidence and action.

      Based on the following project details, provide:

      1. A creative, memorable app name (1-3 words)
      2. A list of 5 similar existing apps/products (to show market validation)
      3. Comprehensive technical information
      4. An inspiring executive summary that sells the vision
      5. Smart feature prioritization for phased development

      Project Details:
      - Description: #{cost_estimate.description}
      - Type: #{app_types}
      - Scale: #{cost_estimate.scale}
      - Key Features: #{features_text}
      - Total Hours: #{cost_estimate.total_hours}
      - Budget: $#{cost_estimate.total_cost}

      Please respond in the following JSON format only (no markdown, no explanation):
      {
        "app_name": "Creative App Name",
        "similar_apps": [
          {"name": "App 1", "description": "Brief description of what it does"},
          {"name": "App 2", "description": "Brief description of what it does"},
          {"name": "App 3", "description": "Brief description of what it does"},
          {"name": "App 4", "description": "Brief description of what it does"},
          {"name": "App 5", "description": "Brief description of what it does"}
        ],
        "technical_info": {
          "application_type": "Brief type description",
          "project_scale": "MVP/Full Product",
          "development_approach": "Detailed development approach (2-3 sentences about methodology, sprints, focus areas)",
          "key_technology_areas": "Comma-separated list of technology areas like Authentication, Core Features, Integrations, Analytics, UI/UX",
          "estimated_timeline": "X weeks with Y developers",
          "total_hours": "XXX hours across all development phases"
        },
        "executive_summary": {
          "problem_statement": "Clear, compelling description of the problem this solves (2-3 sentences, highlighting pain points and market need)",
          "proposed_solution": "How this app elegantly solves the problem (2-3 sentences, emphasizing unique value and innovation)",
          "key_value_propositions": [
            "Value proposition 1 (one sentence, benefit-focused)",
            "Value proposition 2 (one sentence, benefit-focused)",
            "Value proposition 3 (one sentence, benefit-focused)",
            "Value proposition 4 (one sentence, benefit-focused)"
          ],
          "roi_potential": "Exciting description of ROI and business potential (2-3 sentences, highlighting revenue opportunities, cost savings, market opportunity, scalability potential - be optimistic and encouraging)"
        },
        "feature_prioritization": {
          "phase_1_mvp": {
            "timeline": "X weeks",
            "description": "Essential features to validate the concept and get to market fast",
            "features": ["Feature 1", "Feature 2", "Feature 3", "..."]
          },
          "phase_2_growth": {
            "timeline": "X weeks",
            "description": "Features to drive user engagement and market expansion",
            "features": ["Feature 1", "Feature 2", "Feature 3", "..."]
          },
          "phase_3_scale": {
            "timeline": "X weeks",
            "description": "Advanced capabilities for market leadership",
            "features": ["Feature 1", "Feature 2", "Feature 3", "..."]
          }
        }
      }

      Guidelines:
      - Be ENTHUSIASTIC and ENCOURAGING throughout
      - Highlight OPPORTUNITIES and POTENTIAL
      - Show how similar apps validate the market (they prove demand exists!)
      - Emphasize the VALUE of building this now
      - Make ROI potential exciting and realistic
      - Use positive, action-oriented language
      - Never say things like "challenging", "difficult", "risky" - instead say "exciting opportunity", "manageable", "proven approach"
      - Make clients feel confident that building this is a GREAT decision
    PROMPT
  end

  def analyze_with_claude(prompt, max_tokens = 2048)
    return nil if @api_key.blank?

    begin
      uri = URI('https://api.anthropic.com/v1/messages')

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['x-api-key'] = @api_key
      request['anthropic-version'] = '2023-06-01'

      request.body = {
        model: @model,
        max_tokens: max_tokens,
        messages: [
          {
            role: 'user',
            content: prompt
          }
        ]
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 60) do |http|
        http.request(request)
      end

      if response.code == '200'
        parsed = JSON.parse(response.body)
        text = parsed.dig('content', 0, 'text')
        return text
      else
        Rails.logger.error("Anthropic API error: #{response.code} - #{response.body}")
        return nil
      end
    rescue => e
      Rails.logger.error("Claude analysis error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      return nil
    end
  end

  def parse_analysis_response(response)
    # Extract JSON from response (it might be wrapped in markdown code blocks)
    json_match = response.match(/```json\s*(.*?)\s*```/m) || response.match(/\{.*\}/m)
    return nil unless json_match

    json_str = json_match[1] || json_match[0]
    JSON.parse(json_str)
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse Claude response: #{e.message}")
    Rails.logger.error("Response was: #{response}")
    nil
  end

  def generate_web_mockup_html(cost_estimate, app_name)
    features = cost_estimate.proposed_features_array.presence || cost_estimate.features
    feature_names = features.first(4).map { |f| f['name'] || f[:name] }

    <<~HTML
      <div class="mockup-container" style="margin: 40px 0; page-break-inside: avoid;">
        <h3 style="text-align: center; color: #1e40af; margin-bottom: 30px; font-size: 24px;">Web Application Mockup</h3>
        <div class="browser-mockup" style="max-width: 900px; margin: 0 auto; border: 3px solid #e5e7eb; border-radius: 8px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.1);">
          <!-- Browser Chrome -->
          <div style="background: #f3f4f6; padding: 12px 20px; border-bottom: 1px solid #d1d5db; display: flex; align-items: center; gap: 8px;">
            <div style="display: flex; gap: 6px;">
              <div style="width: 12px; height: 12px; border-radius: 50%; background: #ef4444;"></div>
              <div style="width: 12px; height: 12px; border-radius: 50%; background: #f59e0b;"></div>
              <div style="width: 12px; height: 12px; border-radius: 50%; background: #10b981;"></div>
            </div>
            <div style="flex: 1; text-align: center; color: #6b7280; font-size: 12px;">#{app_name}.com</div>
          </div>

          <!-- Header -->
          <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px 40px; color: white;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
              <h1 style="font-size: 28px; margin: 0; font-weight: bold;">#{app_name}</h1>
              <div style="display: flex; gap: 20px; font-size: 14px;">
                <span>Home</span>
                <span>Features</span>
                <span>Pricing</span>
                <span>Contact</span>
              </div>
            </div>
            <p style="font-size: 18px; margin: 0; opacity: 0.9;">#{cost_estimate.description.truncate(100)}</p>
          </div>

          <!-- Content Area -->
          <div style="padding: 40px; background: white;">
            <h2 style="color: #1f2937; margin-bottom: 25px; font-size: 22px;">Key Features</h2>
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">
              #{feature_names.map { |feature|
                <<~FEATURE
                  <div style="padding: 20px; border: 1px solid #e5e7eb; border-radius: 8px; background: #f9fafb;">
                    <div style="width: 40px; height: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 8px; margin-bottom: 12px;"></div>
                    <h3 style="color: #1f2937; font-size: 16px; margin: 0 0 8px 0;">#{feature}</h3>
                    <p style="color: #6b7280; font-size: 13px; margin: 0; line-height: 1.5;">Streamlined and efficient #{feature.downcase} functionality</p>
                  </div>
                FEATURE
              }.join}
            </div>
          </div>
        </div>
      </div>
    HTML
  end

  def generate_mobile_mockup_html(cost_estimate, app_name)
    features = cost_estimate.proposed_features_array.presence || cost_estimate.features
    feature_names = features.first(3).map { |f| f['name'] || f[:name] }

    <<~HTML
      <div class="mockup-container" style="margin: 40px 0; page-break-inside: avoid;">
        <h3 style="text-align: center; color: #1e40af; margin-bottom: 30px; font-size: 24px;">Mobile Application Mockup</h3>
        <div style="display: flex; justify-content: center; gap: 30px; flex-wrap: wrap;">
          <!-- iPhone Mockup -->
          <div class="iphone-mockup" style="width: 280px; background: #1f2937; border-radius: 35px; padding: 12px; box-shadow: 0 20px 50px rgba(0,0,0,0.3);">
            <!-- Notch -->
            <div style="background: black; height: 25px; border-radius: 0 0 20px 20px; margin: -12px -12px 8px -12px; display: flex; justify-content: center;">
              <div style="width: 120px; height: 25px; background: #1f2937; border-radius: 0 0 15px 15px;"></div>
            </div>

            <!-- Screen -->
            <div style="background: white; border-radius: 25px; overflow: hidden; height: 550px;">
              <!-- Status Bar -->
              <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 15px 20px; color: white; font-size: 11px; display: flex; justify-content: space-between;">
                <span>9:41</span>
                <div style="display: flex; gap: 4px; align-items: center;">
                  <span>📶</span>
                  <span>📡</span>
                  <span>🔋</span>
                </div>
              </div>

              <!-- App Header -->
              <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 25px 20px; color: white;">
                <h2 style="margin: 0 0 8px 0; font-size: 24px; font-weight: bold;">#{app_name}</h2>
                <p style="margin: 0; font-size: 13px; opacity: 0.9;">#{cost_estimate.description.truncate(60)}</p>
              </div>

              <!-- Content -->
              <div style="padding: 20px;">
                #{feature_names.map.with_index { |feature, index|
                  <<~FEATURE
                    <div style="margin-bottom: 15px; padding: 15px; background: #f9fafb; border-radius: 12px; border-left: 4px solid #667eea;">
                      <div style="display: flex; align-items: center; gap: 12px;">
                        <div style="width: 35px; height: 35px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 50%; display: flex; align-items: center; justify-content: center; color: white; font-weight: bold; font-size: 14px;">#{index + 1}</div>
                        <div style="flex: 1;">
                          <h4 style="margin: 0 0 4px 0; color: #1f2937; font-size: 14px;">#{feature}</h4>
                          <p style="margin: 0; color: #6b7280; font-size: 11px;">Tap to explore</p>
                        </div>
                      </div>
                    </div>
                  FEATURE
                }.join}
              </div>
            </div>

            <!-- Home Indicator -->
            <div style="height: 5px; background: white; width: 120px; margin: 8px auto; border-radius: 10px; opacity: 0.8;"></div>
          </div>
        </div>
      </div>
    HTML
  end
end
