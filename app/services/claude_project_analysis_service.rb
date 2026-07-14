require "net/http"
require "json"
require "openai"

# Builds the cost estimate (features + hours) that drives the report.
# Provider strategy: try OpenAI gpt-5.5 first; if it errors or comes back empty,
# fall back to Claude (claude-sonnet-4-6). Class name kept for callers.
class ClaudeProjectAnalysisService
  CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"
  CLAUDE_MODEL   = "claude-sonnet-4-6"
  OPENAI_MODEL   = "gpt-5.5"

  def initialize
    @openai_key = ENV["OPENAI_API_KEY"].presence || Rails.application.credentials.OPENAI_API_KEY
    @claude_key = Rails.application.credentials.dig(:anthropic, :api_key) || ENV["ANTHROPIC_API_KEY"]
  end
  
  def analyze_project(app_type:, description:, scale: 'moderate', include_design: false)
    begin
      prompt = build_analysis_prompt(app_type, description, scale, include_design)
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
  
  def build_analysis_prompt(app_type, description, scale, include_design)
    app_type_context = get_app_type_context(app_type)
    scale_context = get_scale_context(scale)
    design_context = include_design ? get_design_context() : ""
    
    adjustment_factor = get_scale_adjustment(scale)
    
    <<~PROMPT
      You are tasked with providing a detailed cost and time estimate for a software development company.
      Your estimates should be based considering the developer is a senior developer.
      Your estimates should give range of hours best case and worst case.
      #{adjustment_factor}
      Use the following input data to generate a JSON object with the estimate.
      
      The basic idea of the app:
      #{description}
      
      Additional details:
      - Platform Type: #{app_type_context}
      - Project Scale: #{scale_context}
      #{design_context}
      
      Generate an extensive scope of the complete project, and then based on the scope generate as many features for the frontend, backend#{include_design ? ", and app design" : ""} based on the app requirements.
      
      Guidelines:
      Add the relevant App Features that are necessary to meet the app requirements and goals.
      
      Return ONLY a valid JSON response with the following structure:
      {
        "project_name": "suggested_project_name_based_on_description",
        "project_overview": "comprehensive_project_overview_paragraph",
        "technical_information_summary": "detailed_technical_approach_and_architecture_description",
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
        "estimated_timeline_weeks": calculated_timeline_in_weeks,
        "team_composition": "recommended_team_size_and_roles",
        "development_methodology": "suggested_development_approach",
        "key_technology_areas": "main_technology_categories_as_comma_separated_string",
        "assumptions": "key assumptions made in the estimate",
        "notes": "additional considerations or recommendations"
      }
      
      Feature Categories Guidelines:
      - Frontend Features: User interface components, responsive design, user interactions
      - Backend Features: APIs, databases, server logic, authentication, integrations
      #{include_design ? "- UI/UX Design Features: User research, wireframes, high-fidelity mockups, design systems, prototyping" : ""}
      - Break down into logical categories (Authentication, Content Management, Communication, Analytics, etc.)
      
      Detailed Requirements for Each Field:
      
      project_name: Generate a concise, professional project name based on the app concept (2-4 words)
      
      project_overview: Write a comprehensive paragraph (3-4 sentences) describing:
      - What the app does and its main purpose
      - Target audience and key value proposition
      - Core functionality and user experience
      
      technical_information_summary: Provide detailed technical overview including:
      - Development approach and methodology (#{get_scale_methodology(scale)})
      - Architecture and technology stack considerations
      - Platform-specific implementation details
      - Team structure and development timeline
      - Key technology areas and integration points
      
      estimated_timeline_weeks: Calculate realistic timeline based on total hours (assuming 40-hour work weeks with team efficiency)
      
      team_composition: Specify recommended team size and roles for #{scale.upcase} project
      
      development_methodology: Describe the development approach suitable for this project scale
      
      key_technology_areas: List main categories like "Authentication, User Interface, Backend API, Database, Payment Processing" etc.
      
      Estimation Guidelines:
      - Be realistic and include buffer time for testing, debugging, and deployment
      - Consider responsive design for web applications
      - Consider app store submission time for mobile apps  
      - Include basic documentation and code review time
      - Make sure estimates are tailored to the specified platform type
      - Do not include any features for Testing/Debugging/CI-CD Pipelines
      #{include_design ? "- If Design is included, focus on UI/UX designs using Figma, NO wireframes or sketches" : "- If Design Status is Not Chosen, skip providing any design-related estimates"}
      
      IMPORTANT: Ensure total hours align with the specified project scale:
      #{get_scale_hours_guidance(scale)}
      
      Return only the JSON object. Do not include any markdown, text, or other formatting. The keys should be in lowercase.
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
  
  def get_design_context
    "- Design Status: UI/UX Design Required - Include professional UI/UX design using Figma"
  end
  
  def get_scale_adjustment(scale)
    case scale
    when 'mvp'
      "Apply a **strict 5% increase** to the hours you provide."
    when 'moderate'
      "Apply a **strict 5% reduction** to the hours you provide."
    when 'enterprise'
      "Apply optimistic estimates for the frontend and backend features."
    else
      ""
    end
  end
  
  def get_scale_methodology(scale)
    case scale
    when 'mvp'
      "rapid prototyping with core functionality focus, agile methodology with 2-week sprints"
    when 'moderate'
      "balanced development with comprehensive testing, agile methodology with full feature implementation"
    when 'enterprise'
      "enterprise-grade architecture with extensive quality assurance, security protocols, and scalability planning"
    else
      "standard agile development with industry best practices"
    end
  end

  def get_scale_hours_guidance(scale)
    case scale
    when 'mvp'
      "* MVP: 300-600 hours (basic functionality, minimal features)"
    when 'moderate'
      "* Moderate Scale: 600-1500 hours (standard features, good UX/UI)"
    when 'enterprise'
      "* Enterprise: 1500+ hours (advanced features, high scalability, extensive testing)"
    else
      "* Standard: 600-1500 hours (balanced feature set)"
    end
  end
  
  # OpenAI first, Claude as fallback.
  def make_api_request(prompt)
    content = openai_completion(prompt)
    content = claude_completion(prompt) if content.blank?
    content.present? ? { success: true, content: content } : { success: false, error: "AI providers unavailable" }
  end

  def openai_completion(prompt)
    return nil if @openai_key.blank?
    client = OpenAI::Client.new(access_token: @openai_key, request_timeout: 180)
    # reasoning_effort low + large budget: otherwise gpt-5.5 spends the whole
    # completion budget reasoning and returns an empty body on this big prompt.
    response = client.chat(parameters: {
      model: OPENAI_MODEL,
      messages: [{ role: "user", content: prompt }],
      max_completion_tokens: 16000,
      reasoning_effort: "low"
    })
    response.dig("choices", 0, "message", "content").presence
  rescue => e
    Rails.logger.warn("ClaudeProjectAnalysisService: OpenAI failed, falling back to Claude: #{e.message}")
    nil
  end

  def claude_completion(prompt)
    return nil if @claude_key.blank?
    uri = URI(CLAUDE_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 120

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = @claude_key
    request['anthropic-version'] = '2023-06-01'
    request.body = { model: CLAUDE_MODEL, max_tokens: 4000, messages: [{ role: "user", content: prompt }] }.to_json

    response = http.request(request)
    if response.code == '200'
      JSON.parse(response.body).dig('content', 0, 'text').presence
    else
      Rails.logger.error("Claude estimate API error: #{response.code} - #{response.body}")
      nil
    end
  rescue => e
    Rails.logger.error("Claude estimate failed: #{e.message}")
    nil
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
        project_name: parsed['project_name'] || '',
        project_overview: parsed['project_overview'] || '',
        technical_information_summary: parsed['technical_information_summary'] || '',
        estimated_timeline_weeks: parsed['estimated_timeline_weeks'] || 0,
        team_composition: parsed['team_composition'] || '',
        development_methodology: parsed['development_methodology'] || '',
        key_technology_areas: parsed['key_technology_areas'] || '',
        assumptions: parsed['assumptions'] || '',
        notes: parsed['notes'] || ''
      }
    rescue JSON::ParserError => e
      { success: false, error: "Failed to parse analysis response: #{e.message}" }
    end
  end
end