class ClaudeProjectAnalysisService
  CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"
  CLAUDE_MODEL = "claude-3-5-sonnet-20241022"
  
  def initialize
    @api_key = Rails.application.credentials.dig(:anthropic, :api_key) || ENV['ANTHROPIC_API_KEY']
    raise "Anthropic API key not configured" unless @api_key
  end
  
  def analyze_project(app_type:, description:, scale: 'moderate')
    begin
      prompt = build_analysis_prompt(app_type, description, scale)
      response = make_api_request(prompt)
      
      if response[:success]
        parse_analysis_response(response[:content])
      else
        { success: false, error: response[:error] }
      end
    rescue => e
      Rails.logger.error "Claude API Error: #{e.message}"
      { success: false, error: "Analysis service temporarily unavailable" }
    end
  end
  
  private
  
  def build_analysis_prompt(app_type, description, scale)
    app_type_context = get_app_type_context(app_type)
    scale_context = get_scale_context(scale)
    
    <<~PROMPT
      You are a senior software architect and project estimator. Analyze the following project requirements and provide a detailed breakdown of features and time estimates.

      Application Type: #{app_type_context}
      Project Scale: #{scale_context}
      Project Description: #{description}

      Please analyze this project and return ONLY a valid JSON response with the following structure:
      {
        "features": [
          {
            "category": "category_name",
            "name": "feature_name",
            "description": "brief_description",
            "hours": estimated_hours_as_number,
            "complexity": "Low|Medium|High"
          }
        ],
        "total_hours": total_estimated_hours_as_number,
        "assumptions": "key assumptions made in the estimate",
        "notes": "additional considerations or recommendations"
      }

      Guidelines for estimation:
      - Be realistic and include buffer time for testing, debugging, and deployment
      - Consider both frontend and backend development time
      - Include time for basic security implementations
      - Factor in responsive design for web applications
      - Consider app store submission time for mobile apps
      - Include basic documentation and code review time
      - Break down into logical feature categories (Authentication, UI/UX, Backend API, Database, Testing, etc.)
      - IMPORTANT: Ensure total hours align with the specified project scale:
        * MVP: 300-600 hours (basic functionality, minimal features)
        * Moderate Scale: 600-1500 hours (standard features, good UX/UI)
        * Enterprise: 1500+ hours (advanced features, high scalability, extensive testing)

      IMPORTANT: Return ONLY the JSON response, no other text or explanations.
    PROMPT
  end
  
  def get_app_type_context(app_type)
    contexts = {
      'web' => 'Web Application (HTML/CSS/JavaScript frontend with backend API)',
      'mobile_ios' => 'Native iOS Mobile Application (Swift/SwiftUI)',
      'mobile_android' => 'Native Android Mobile Application (Kotlin/Java)',
      'mobile_cross' => 'Cross-platform Mobile Application (React Native/Flutter)',
      'desktop' => 'Desktop Application (Electron/Native)',
      'ecommerce' => 'E-commerce Platform with payment processing',
      'crm' => 'Customer Relationship Management System',
      'api' => 'Backend API/Web Service',
      'custom' => 'Custom Software Solution'
    }
    
    contexts[app_type] || app_type
  end
  
  def get_scale_context(scale)
    contexts = {
      'mvp' => 'MVP (300-600 hours) - Basic functionality with minimal features, core features only',
      'moderate' => 'Moderate Scale (600-1500 hours) - Standard features with good UX/UI, well-rounded application',
      'enterprise' => 'Enterprise (1500+ hours) - Advanced features, high scalability, extensive testing, complex integrations'
    }
    
    contexts[scale] || 'Moderate Scale'
  end
  
  def make_api_request(prompt)
    uri = URI(CLAUDE_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = @api_key
    request['anthropic-version'] = '2023-06-01'
    
    request.body = {
      model: CLAUDE_MODEL,
      max_tokens: 4000,
      messages: [
        {
          role: "user",
          content: prompt
        }
      ]
    }.to_json
    
    response = http.request(request)
    
    if response.code == '200'
      result = JSON.parse(response.body)
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
  
  def parse_analysis_response(content)
    begin
      # Extract JSON from the response (in case there's extra text)
      json_match = content.match(/\{.*\}/m)
      return { success: false, error: "No valid JSON found in response" } unless json_match
      
      parsed = JSON.parse(json_match[0])
      
      # Validate required fields
      unless parsed['features'].is_a?(Array) && parsed['total_hours'].is_a?(Numeric)
        return { success: false, error: "Invalid response format" }
      end
      
      # Ensure features have required fields
      features = parsed['features'].map do |feature|
        {
          'category' => feature['category'] || 'General',
          'name' => feature['name'] || 'Unnamed Feature',
          'description' => feature['description'] || '',
          'hours' => feature['hours']&.to_i || 0,
          'complexity' => feature['complexity'] || 'Medium'
        }
      end
      
      {
        success: true,
        features: features,
        total_hours: parsed['total_hours'].to_i,
        assumptions: parsed['assumptions'] || '',
        notes: parsed['notes'] || ''
      }
    rescue JSON::ParserError => e
      { success: false, error: "Failed to parse analysis response: #{e.message}" }
    end
  end
end