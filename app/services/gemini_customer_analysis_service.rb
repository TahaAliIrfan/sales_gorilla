require 'net/http'
require 'json'

class GeminiCustomerAnalysisService
  attr_reader :api_key, :model

  def initialize
    @api_key = Rails.application.credentials.dig(:GEMINI_API_KEY) || ENV['GEMINI_API_KEY']
    @model = "gemini-1.5-flash"
    
    if @api_key.blank?
      Rails.logger.error("Gemini API key is not configured")
    end
  end

  def analyze_customer_message(chat_id, message_body, phone_number)
    return nil if @api_key.blank? || phone_number.blank?

    content = format_phone_analysis_content(chat_id, message_body, phone_number)
    analyze_with_prompt(content, phone_analysis_prompt)
  end

  def analyze_phone_for_timezone(phone_number)
    return nil if @api_key.blank? || phone_number.blank?

    content = "Phone Number: #{phone_number}"
    analyze_with_prompt(content, phone_timezone_prompt)
  end

  def analyze_with_prompt(content, system_prompt, temperature = 0.7)
    return nil if @api_key.blank? || content.blank? || system_prompt.blank?

    begin
      response = make_analysis_request(content, system_prompt, temperature)
      
      if response && response['success']
        response['data']
      else
        Rails.logger.error("Gemini API error: #{response['error'] if response}")
        nil
      end
    rescue => e
      Rails.logger.error("Gemini analysis error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      nil
    end
  end

  private

  def format_phone_analysis_content(chat_id, message_body, phone_number)
    "WhatsApp Chat ID: #{chat_id}\nPhone Number: #{phone_number}\nMessage: #{message_body}"
  end

  def make_analysis_request(content, system_prompt, temperature = 0.7)
    uri = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{api_key}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Post.new("#{uri.path}?#{uri.query}", {
      'Content-Type' => 'application/json'
    })

    req.body = {
      contents: [
        {
          parts: [
            {
              text: "#{system_prompt}\n\n#{content}"
            }
          ]
        }
      ],
      generationConfig: {
        temperature: temperature,
        responseMimeType: "application/json"
      }
    }.to_json

    response = http.request(req)
    parse_response(response)
  end

  def parse_response(response)
    if response.code == '200'
      body = JSON.parse(response.body)
      content = body.dig('candidates', 0, 'content', 'parts', 0, 'text')
      
      if content
        begin
          json_data = JSON.parse(content)
          json_data = symbolize_keys(json_data)
          { 'success' => true, 'data' => json_data }
        rescue JSON::ParserError => e
          { 'success' => false, 'error' => "Failed to parse JSON response: #{e.message}" }
        end
      else
        { 'success' => false, 'error' => "No content in response" }
      end
    else
      { 'success' => false, 'error' => "API error: #{response.code} - #{response.body}" }
    end
  end

  def symbolize_keys(hash)
    hash.transform_keys(&:to_sym)
  end

  def phone_analysis_prompt
    <<~PROMPT
    You are an AI assistant that analyzes phone numbers and WhatsApp messages to extract customer information for a tech agency's CRM system.
    
    Your primary task is to analyze the provided phone number to identify:
    
    1. Country: Identify the country associated with the phone number's country code.
    2. Timezone: Determine the most likely timezone for that country/region.
    3. Preferred calling time: Suggest appropriate business hours for calling customers in that timezone.
    
    Additionally, if a message is provided, analyze it to extract:
    
    4. Name: The customer's name (if present in the message), otherwise write 'N/A'
    5. Email: The customer's email address (if present in the message), otherwise write 'N/A'
    6. Idea description: Extract any description of app or software the customer might be interested in, otherwise write 'N/A'
    
    For phone number analysis:
    - Consider country codes (e.g., +1 for US/Canada, +44 for UK, +91 for India, +92 for Pakistan, etc.)
    - For countries with multiple timezones, suggest the most populous timezone
    - Consider cultural factors when suggesting preferred calling times
    - Be specific about timezone abbreviations (e.g., EST, GMT, IST, PKT)
    
    Return your analysis as a valid JSON object with these fields. Be concise and extract only what's clearly indicated.
    
    Example format:
    {
      "name": "John Smith",
      "email": "john@example.com",
      "country": "United States",
      "timezone": "America/New_York",
      "preferred_calling_time": "9 AM - 5 PM EST (Monday to Friday)",
      "idea_description": "Mobile app for fitness tracking"
    }
    PROMPT
  end

  def phone_timezone_prompt
    <<~PROMPT
    You are an AI assistant that specializes in analyzing phone numbers to extract accurate timezone and calling preferences for a tech agency's CRM system.

    Your task is to analyze the provided phone number to identify ONLY these specific details:
    
    1. Country: Identify the country associated with the phone number's country code.
    
    2. Timezone: Determine the most likely timezone for that country/region.
       - Use standard timezone identifiers (e.g., America/New_York, Europe/London, Asia/Tokyo, Asia/Karachi)
       - For countries with multiple timezones, suggest the most populous timezone
       - Be as precise as possible with the timezone
    
    3. Preferred calling time: Suggest appropriate business hours for calling customers in that timezone.
       - Consider cultural and business norms in the customer's region
       - Be specific about the time range and include the timezone abbreviation
       - Format as: "9 AM - 5 PM EST (Monday to Friday)" or similar
       - For Pakistan, consider "10 AM - 6 PM PKT (Monday to Friday)" as standard business hours
    
    For phone number analysis:
    - Analyze country codes thoroughly (e.g., +1 for US/Canada, +44 for UK, +91 for India, +92 for Pakistan, etc.)
    - Consider number formatting patterns to identify specific regions within countries
    - For countries with multiple timezones (like the US, Russia, Australia), try to determine the specific region based on area codes if possible
    - Consider regional business customs when suggesting calling times
    - If the phone number format doesn't match any known country pattern, mark as "N/A"
    
    Return your analysis as a valid JSON object with ONLY these fields:
    {
      "country": "Pakistan",
      "timezone": "Asia/Karachi",
      "preferred_calling_time": "10 AM - 6 PM PKT (Monday to Friday)"
    }
    
    Be concise, accurate, and focus only on extracting timezone and calling time information from the phone number pattern.
    PROMPT
  end
end