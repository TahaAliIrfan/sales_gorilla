require 'net/http'
require 'json'

class DeepSeekRecordingService
  attr_reader :api_key, :model

  def initialize
    @api_key = Rails.application.credentials.dig(:DEEPSEEK_API_KEY) || ENV['DEEPSEEK_API_KEY']
    @model = "deepseek-chat"
    
    if @api_key.blank?
      Rails.logger.error("DeepSeek API key is not configured")
    end
  end

  def analyze_recording(recording)
    return nil unless recording.transcribed?

    response = make_analysis_request(recording)
    if response && response['success']
      create_ai_analysis(recording, response['data'])
    else
      Rails.logger.error("DeepSeek API error: #{response['error'] if response}")
      nil
    end
  rescue => e
    Rails.logger.error("DeepSeek recording service error: #{e.message}")
    nil
  end

  private

  def create_ai_analysis(recording, analysis_data)
    recording.ai_analyses.create!(
      summary: analysis_data['summary'],
      interest_score: analysis_data['interest_score'],
      improvement_points: analysis_data['improvement_points'],
      next_steps: analysis_data['next_steps'],
      followup_message: analysis_data['followup_message'],
      followup_email: analysis_data['followup_email']
    )
  end

  def make_analysis_request(recording)
    uri = URI.parse("https://api.deepseek.com/v1/chat/completions")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Post.new(uri.path, {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{api_key}"
    })

    req.body = {
      model: model,
      messages: [
        { role: "system", content: system_prompt },
        { 
          role: "user", 
          content: "Here is a transcript of a sales call for a tech agency selling services:\n\n#{recording.transcription.to_s}"
        }
      ],
      temperature: 0.7,
      response_format: { type: "json_object" }
    }.to_json

    response = http.request(req)
    parse_response(response)
  end

  def parse_response(response)
    if response.code == '200'
      body = JSON.parse(response.body)
      content = body['choices'][0]['message']['content']
      
      begin
        analysis = JSON.parse(content)
        { 'success' => true, 'data' => analysis }
      rescue JSON::ParserError => e
        { 'success' => false, 'error' => "Failed to parse JSON response: #{e.message}" }
      end
    else
      { 'success' => false, 'error' => "API error: #{response.code} - #{response.body}" }
    end
  end

  def system_prompt
    <<~PROMPT
    You are an AI assistant that analyzes sales call transcripts for a tech agency selling development and software services. 
    Your task is to provide structured feedback and insights about the call.

    Only provide the answers if it is a Valid sales call if it is some answering machine or something then in summary should just say to retry calling
    
    Please analyze the transcript and provide the following information in JSON format:
    
    1. summary: A concise summary of the call (max 150 words)
    2. interest_score: Rate the customer's interest level from 1-5 where 1 means not interested and 5 means almost ready to start
    3. improvement_points: Suggestions for how the caller can improve their approach and sales technique
    4. next_steps: Recommended actions the sales representative should take
    5. followup_message: A draft WhatsApp or text message that could be sent as a follow-up
    6. followup_email: A draft email that could be sent as a follow-up
    
    Your response should be valid JSON formatted as follows:
    {
      "summary": "string",
      "interest_score": number,
      "improvement_points": "string",
      "next_steps": "string",
      "followup_message": "string",
      "followup_email": "string"
    }
    PROMPT
  end
end