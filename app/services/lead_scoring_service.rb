class LeadScoringService
  GEOGRAPHIC_SCORES = {
    # First World Countries - Higher scores (40-50 points out of 50)
    'UNITED STATES' => 50, 'USA' => 50, 'US' => 50,
    'CANADA' => 48, 'CA' => 48,
    'UNITED KINGDOM' => 47, 'UK' => 47, 'GB' => 47,
    'GERMANY' => 46, 'DE' => 46,
    'FRANCE' => 45, 'FR' => 45,
    'NETHERLANDS' => 45, 'NL' => 45,
    'SWITZERLAND' => 50, 'CH' => 50,
    'SWEDEN' => 44, 'SE' => 44,
    'NORWAY' => 46, 'NO' => 46,
    'DENMARK' => 44, 'DK' => 44,
    'FINLAND' => 43, 'FI' => 43,
    'AUSTRALIA' => 45, 'AU' => 45,
    'NEW ZEALAND' => 43, 'NZ' => 43,
    'IRELAND' => 42, 'IE' => 42,
    'AUSTRIA' => 42, 'AT' => 42,
    'BELGIUM' => 41, 'BE' => 41,
    'JAPAN' => 44, 'JP' => 44,
    'SOUTH KOREA' => 40, 'KR' => 40,
    'SINGAPORE' => 42, 'SG' => 42,
    'HONG KONG' => 40, 'HK' => 40,
    'ISRAEL' => 38, 'IL' => 38,
    
    # Gulf Countries - High scores (35-42 points)
    'UNITED ARAB EMIRATES' => 42, 'UAE' => 42, 'AE' => 42,
    'SAUDI ARABIA' => 38, 'SA' => 38,
    'QATAR' => 40, 'QA' => 40,
    'KUWAIT' => 38, 'KW' => 38,
    'BAHRAIN' => 36, 'BH' => 36,
    'OMAN' => 35, 'OM' => 35,
    
    # Emerging Markets - Medium scores (25-35 points)
    'CHINA' => 32, 'CN' => 32,
    'TAIWAN' => 30, 'TW' => 30,
    'MALAYSIA' => 28, 'MY' => 28,
    'THAILAND' => 26, 'TH' => 26,
    'INDONESIA' => 25, 'ID' => 25,
    'PHILIPPINES' => 24, 'PH' => 24,
    'VIETNAM' => 23, 'VN' => 23,
    'BRAZIL' => 30, 'BR' => 30,
    'MEXICO' => 28, 'MX' => 28,
    'RUSSIA' => 25, 'RU' => 25,
    'SOUTH AFRICA' => 26, 'ZA' => 26,
    'TURKEY' => 27, 'TR' => 27,
    'POLAND' => 32, 'PL' => 32,
    'CZECH REPUBLIC' => 30, 'CZ' => 30,
    'ROMANIA' => 25, 'RO' => 25,
    'BULGARIA' => 22, 'BG' => 22,
    'CROATIA' => 28, 'HR' => 28,
    'HUNGARY' => 29, 'HU' => 29,
    'ESTONIA' => 32, 'EE' => 32,
    'LATVIA' => 30, 'LV' => 30,
    'LITHUANIA' => 31, 'LT' => 31,
    'SLOVENIA' => 30, 'SI' => 30,
    'SLOVAKIA' => 28, 'SK' => 28,
    
    # Subcontinent & Developing Countries - Lower scores (10-25 points)
    'PAKISTAN' => 15, 'PK' => 15,
    'INDIA' => 20, 'IN' => 20,
    'BANGLADESH' => 12, 'BD' => 12,
    'SRI LANKA' => 14, 'LK' => 14,
    'NEPAL' => 10, 'NP' => 10,
    'AFGHANISTAN' => 8, 'AF' => 8,
    'IRAN' => 16, 'IR' => 16,
    'IRAQ' => 12, 'IQ' => 12,
    'SYRIA' => 10, 'SY' => 10,
    'LEBANON' => 18, 'LB' => 18,
    'JORDAN' => 20, 'JO' => 20,
    'EGYPT' => 18, 'EG' => 18,
    'MOROCCO' => 16, 'MA' => 16,
    'ALGERIA' => 14, 'DZ' => 14,
    'TUNISIA' => 17, 'TN' => 17,
    'LIBYA' => 12, 'LY' => 12,
    'NIGERIA' => 15, 'NG' => 15,
    'KENYA' => 16, 'KE' => 16,
    'GHANA' => 18, 'GH' => 18,
    'UGANDA' => 12, 'UG' => 12,
    'ETHIOPIA' => 10, 'ET' => 10,
    'TANZANIA' => 13, 'TZ' => 13,
    'ZIMBABWE' => 11, 'ZW' => 11,
    'ZAMBIA' => 12, 'ZM' => 12,
    'BOTSWANA' => 20, 'BW' => 20,
    'NAMIBIA' => 18, 'NA' => 18
  }.freeze
  
  def initialize(customer)
    @customer = customer
  end
  
  def calculate_score
    geographic_score = calculate_geographic_score
    description_score = calculate_description_score
    
    total_score = [geographic_score + description_score, 100].min
    
    {
      total_score: total_score,
      geographic_score: geographic_score,
      description_score: description_score,
      breakdown: {
        country: @customer.country,
        has_description: @customer.idea_description.present?,
        description_quality: description_score > 25 ? 'High' : description_score > 15 ? 'Medium' : 'Low'
      }
    }
  end
  
  private
  
  def calculate_geographic_score
    return 25 unless @customer.country.present? # Default middle score if no country
    
    country_normalized = @customer.country.strip.upcase
    
    # Direct lookup
    score = GEOGRAPHIC_SCORES[country_normalized]
    return score if score
    
    # Try partial matches for compound country names
    GEOGRAPHIC_SCORES.each do |key, value|
      if country_normalized.include?(key) || key.include?(country_normalized)
        return value
      end
    end
    
    # Default score for unlisted countries
    25
  end
  
  def calculate_description_score
    return 0 unless @customer.idea_description.present?
    
    description = @customer.idea_description.strip
    return 0 if description.empty?
    
    # Use AI analysis for description scoring
    ai_score = analyze_description_with_ai(description)
    
    # Fallback to simple scoring if AI fails
    ai_score || calculate_simple_description_score(description)
  end
  
  def analyze_description_with_ai(description)
    # Check if we should use Claude or Gemini
    use_claude = Rails.application.credentials.dig(:claude, :api_key).present?
    use_gemini = Rails.application.credentials.dig(:gemini, :api_key).present?
    
    if use_claude
      analyze_with_claude(description)
    elsif use_gemini
      analyze_with_gemini(description)
    else
      Rails.logger.warn("No AI API keys configured for lead scoring")
      nil
    end
  rescue => e
    Rails.logger.error("AI analysis failed for lead scoring: #{e.message}")
    nil
  end
  
  def analyze_with_claude(description)
    require 'net/http'
    require 'json'
    
    api_key = Rails.application.credentials.dig(:claude, :api_key)
    return nil unless api_key
    
    prompt = build_ai_prompt(description)
    
    uri = URI('https://api.anthropic.com/v1/messages')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = api_key
    request['anthropic-version'] = '2023-06-01'
    
    request.body = {
      model: 'claude-3-haiku-20240307',
      max_tokens: 150,
      messages: [
        {
          role: 'user',
          content: prompt
        }
      ]
    }.to_json
    
    response = http.request(request)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      content = data.dig('content', 0, 'text')
      extract_score_from_response(content)
    else
      Rails.logger.error("Claude API error: #{response.code} - #{response.body}")
      nil
    end
  end
  
  def analyze_with_gemini(description)
    require 'net/http'
    require 'json'
    
    api_key = Rails.application.credentials.dig(:gemini, :api_key)
    return nil unless api_key
    
    prompt = build_ai_prompt(description)
    
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=#{api_key}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    
    request.body = {
      contents: [
        {
          parts: [
            {
              text: prompt
            }
          ]
        }
      ]
    }.to_json
    
    response = http.request(request)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      content = data.dig('candidates', 0, 'content', 'parts', 0, 'text')
      extract_score_from_response(content)
    else
      Rails.logger.error("Gemini API error: #{response.code} - #{response.body}")
      nil
    end
  end
  
  def build_ai_prompt(description)
    <<~PROMPT
      Analyze this business idea description and score it from 0-50 based on:
      1. Clarity and detail (0-15 points)
      2. Market potential and viability (0-15 points)  
      3. Technical complexity and innovation (0-10 points)
      4. Specificity and completeness (0-10 points)
      
      Description: "#{description}"
      
      Respond with just the numeric score (0-50) and a brief one-sentence explanation.
      Example: "Score: 35 - Well-detailed e-commerce platform with clear monetization strategy."
    PROMPT
  end
  
  def extract_score_from_response(content)
    return nil unless content
    
    # Look for "Score: XX" pattern
    if match = content.match(/score:\s*(\d+)/i)
      score = match[1].to_i
      # Clamp between 0 and 50
      [[score, 0].max, 50].min
    else
      # Try to extract any number that looks like a score
      numbers = content.scan(/\b(\d{1,2})\b/).flatten.map(&:to_i)
      valid_scores = numbers.select { |n| n <= 50 }
      valid_scores.first
    end
  end
  
  def calculate_simple_description_score(description)
    score = 0
    word_count = description.split.length
    
    # Length scoring (0-20 points)
    score += case word_count
             when 0..5 then 5
             when 6..15 then 10
             when 16..30 then 15
             when 31..50 then 20
             else 18 # Very long descriptions might be less focused
             end
    
    # Quality indicators (0-30 points)
    quality_keywords = [
      # Business terms
      'revenue', 'profit', 'customers', 'market', 'business', 'sales', 'monetize',
      'subscription', 'enterprise', 'b2b', 'b2c', 'saas',
      
      # Technical terms
      'platform', 'api', 'database', 'integration', 'automation', 'ai', 'ml',
      'mobile', 'web', 'cloud', 'analytics', 'dashboard',
      
      # Project scope terms
      'mvp', 'prototype', 'scalable', 'secure', 'performance', 'user experience',
      'features', 'functionality', 'requirements'
    ]
    
    description_lower = description.downcase
    matched_keywords = quality_keywords.count { |keyword| description_lower.include?(keyword) }
    score += [matched_keywords * 3, 30].min
    
    [score, 50].min
  end
end