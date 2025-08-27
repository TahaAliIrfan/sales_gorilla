class LeadScoringService
  def initialize(customer)
    @customer = customer
  end

  def calculate_score
    response = analyze_with_deepseek(@customer)

    if response
      @customer.update(lead_score: response["total_score"],
                       geographic_score: response["location_score"] + response["name_score"],
                       description_score: response["idea_description_score"])
    end
  end

  private

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

        **NEW SCORING CRITERIA:**

        **1. Description and Data Quality (0-60 points) - HIGHEST PRIORITY**
        - Preferred calling time provided: 0-15 points
        - Description detail and completeness: 0-25 points
        - Market potential and business viability: 0-20 points

        **2. Name-based Ethnicity Score (0-30 points)**
        - 1st World Country Names (Western, European origin): 20-30 points
        - Arabic Names: 10-20 points
        - Subcontinent Names (Indian, Pakistani, Sri Lankan, Bangladeshi): 0-10 points

        **3. Location Score (0-10 points)**
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
          "name_score": "integer value from 0-30",
          "idea_description_score": "integer value from 0-60",
          "explanation": "brief explanation focusing on description quality and name ethnicity assessment"
        }
        ```
      PROMPT
    end
  end
end