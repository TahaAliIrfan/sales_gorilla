class LeadScoringService
  def initialize(customer)
    @customer = customer
  end

  def calculate_score
    response = analyze_with_deepseek(@customer)

    @customer.update(lead_score: response["total_score"],
                     geographic_score: response["location_score"] + response["name_score"],
                     description_score: response["idea_description_score"])
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

    prompt = build_ai_prompt(customer.idea_description, country_name, customer.name)


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

  def build_ai_prompt(description, location, name)
    <<~PROMPT
            Analyze this customer's business idea, including their location and name origin, and score it from 0-100 based on the following criteria:

       **Scoring Criteria:**

      **1. Customer Location Score (0-35 points)**
      - 1st World Country: 35 points
      - 2nd World Country: 0-30 points (variable based on specific location)
      - 3rd World Country: 0-10 points (variable based on specific location)

      **2. Customer Name Origin Score (0-25 points)**
      - 1st World Origin: 25 points
      - 2nd World Origin (e.g., Core Arabic names): 15-20 points (variable)
      - 3rd World Origin: 5-10 points (variable)

      **3. Idea Description Score (0-40 points)**
      - Clarity and detail: 0-15 points
      - Market potential and viability: 0-15 points
      - Technical complexity and innovation: 0-10 points
      - Specificity and completeness: 0-10 points

      **Input:**
      - Customer Location: "#{location}"
      - Customer Name: "#{name}"
      - Idea Description: "#{description}"

      **JSON Response Format:**
      ```json
      {
        "total_score": "integer value from 0-100",
        "location_score": "integer value from 0-35",
        "name_score": "integer value from 0-25",
        "idea_description_score": "integer value from 0-40",
        "explanation": "a brief, one-sentence explanation"
      }

    PROMPT
  end
end