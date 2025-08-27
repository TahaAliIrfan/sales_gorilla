class LeadScoringService
  def initialize(customer)
    @customer = customer
  end

  def calculate_score
    response = analyze_with_deepseek(@customer)

    if response
      base_score = response["total_score"]
      call_bonus = calculate_historical_call_bonus
      ai_analysis_bonus = calculate_historical_ai_analysis_bonus
      
      final_score = [base_score + call_bonus + ai_analysis_bonus, 100].min
      
      @customer.update(lead_score: final_score,
                       geographic_score: response["location_score"] + response["name_score"],
                       description_score: response["idea_description_score"])
    end
  end

  private

  def calculate_historical_call_bonus
    # Count successful calls (duration >= 90 seconds)
    successful_calls = @customer.recordings.where('duration >= ?', 90).count
    
    # Each successful call adds 10 points
    successful_calls * 10
  end

  def calculate_historical_ai_analysis_bonus
    # Get all AI analyses for this customer through recordings
    ai_analyses = AiAnalysis.joins(:recording)
                           .where(recordings: { customer: @customer })
                           .where('interest_score >= ?', 3)
    
    total_bonus = 0
    base_score_for_percentage = @customer.lead_score || 0
    
    ai_analyses.each do |analysis|
      case analysis.interest_score
      when 3
        total_bonus += 5  # Fixed 5-point increase
      when 4, 5
        # 30% increase based on score at time of calculation
        total_bonus += (base_score_for_percentage * 0.30).round
      end
    end
    
    total_bonus
  end

  def extract_json_from_response(response_text)
    return nil unless response_text

    json_match = response_text.match(/```json\s*\n(.*?)\n```/m)
    return nil unless json_match

    begin
      JSON.parse(json_match[1])
    rescue JSON::ParserError
      nil
    end
  end

  def analyze_with_deepseek(customer)
    require 'net/http'
    require 'json'

    api_key = Rails.application.credentials.dig(:DEEPSEEK_API_KEY) || ENV['DEEPSEEK_API_KEY']
    return nil unless api_key

    country_name = if customer.customer_location.present?
                     customer.customer_location.country_name
                   else
                     customer.country
                   end

    prompt = build_ai_prompt(customer.idea_description, country_name, customer.name, customer.lead_source, customer.preferred_calling_time)


    uri = URI.parse("https://api.deepseek.com/v1/chat/completions")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path, {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{api_key}"
    })

    request.body = {
      model: "deepseek-chat",
      messages: [
        {
          role: "user",
          content: prompt
        }
      ]
    }.to_json

    response = http.request(request)

    if response.code == '200'
      data = JSON.parse(response.body)
      content = data.dig('choices', 0, 'message', 'content')
      extract_json_from_response(content)
    else
      Rails.logger.error("DeepSeek API error: #{response.code} - #{response.body}")
      nil
    end
  end

  def build_ai_prompt(description, location, name, lead_source, preferred_calling_time)
    if lead_source == 'WA'
      # Special scoring for WhatsApp leads - location only
      <<~PROMPT
        Analyze this WhatsApp lead based ONLY on location and score from 0-100:

        **Scoring for WhatsApp Leads (Location Only):**
        - 1st World Countries (USA, Canada, UK, Australia, Germany, France, etc.): 80-100 points
        - 2nd Tier Countries (UAE, Saudi Arabia, Qatar, Singapore, etc.): 60-80 points
        - 3rd Tier Countries (India, Pakistan, Bangladesh, Sri Lanka, etc.): 0-10 points
        - Other developing countries: 0-20 points

        **Input:**
        - Customer Location: "#{location}"
        - Lead Source: WhatsApp

        **JSON Response Format:**
        ```json
        {
          "total_score": "integer value from 0-100",
          "location_score": "integer value from 0-100",
          "name_score": 0,
          "idea_description_score": 0,
          "explanation": "WhatsApp lead scored based on location only"
        }
        ```
      PROMPT
    else
      # Standard scoring for non-WhatsApp leads
      <<~PROMPT
        Analyze this customer lead and score it from 0-100 based on the following criteria:

        **SCORING CRITERIA:**

        **1. Project Cost Estimation and Scoring (0-40 points) - HIGHEST PRIORITY**
        First, estimate the project cost based on the description using $30/hour rate:
        - Less than $5,000: 0 points
        - $5,000 - $9,999: 5 points
        - $10,000 - $19,999: 10 points
        - $20,000 - $50,000: 20 points
        - Above $50,000: 40 points

        **2. Description and Data Quality (0-30 points)**
        - Preferred calling time provided: 0-10 points
        - Description detail and completeness: 0-10 points
        - Market potential and business viability: 0-10 points

        **3. Name-based Ethnicity Score (0-20 points)**
        - 1st World Country Names (Western, European origin): 15-20 points
        - Arabic Names: 8-14 points
        - Subcontinent Names (Indian, Pakistani, Sri Lankan, Bangladeshi): 0-7 points

        **4. Location Score (0-10 points)**
        - 1st World Country: 8-10 points
        - 2nd World Country: 4-7 points
        - 3rd World Country: 0-3 points

        **Input:**
        - Customer Location: "#{location}"
        - Customer Name: "#{name}"
        - Idea Description: "#{description}"
        - Preferred Calling Time: "#{preferred_calling_time}"

        **JSON Response Format:**
        ```json
        {
          "total_score": "integer value from 0-100",
          "location_score": "integer value from 0-10",
          "name_score": "integer value from 0-20",
          "idea_description_score": "integer value from 0-30",
          "project_cost_score": "integer value from 0-40",
          "estimated_project_cost": "integer value in USD",
          "explanation": "brief explanation including project cost estimation reasoning"
        }
        ```
      PROMPT
    end
  end
end