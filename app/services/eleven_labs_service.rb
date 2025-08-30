class ElevenLabsService
  def initialize
    @api_key = Rails.application.credentials.dig(:ELEVEN_LABS_API_KEY)
    @agent_id = Rails.application.credentials.dig(:ELEVEN_LABS_AGENT_ID)
    @agent_phone_number_id = Rails.application.credentials.dig(:ELEVEN_LABS_AGENT_PHONE_NUMBER_ID)
    
    unless @api_key && @agent_id && @agent_phone_number_id
      Rails.logger.error("Missing required ElevenLabs credentials")
      raise "ElevenLabs credentials not properly configured"
    end
    
    @base_url = 'https://api.elevenlabs.io/v1'
  end

  def make_outbound_call(to_number)
    uri = URI("#{@base_url}/convai/twilio/outbound-call")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['xi-api-key'] = @api_key
    request['Content-Type'] = 'application/json'
    
    payload = {
      agent_id: @agent_id,
      agent_phone_number_id: @agent_phone_number_id,
      to_number: to_number
    }
    
    request.body = payload.to_json
    
    response = http.request(request)
    
    if response.code.to_i == 200
      Rails.logger.info("Successfully initiated outbound call to #{to_number}")
      JSON.parse(response.body)
    else
      Rails.logger.error("Failed to initiate outbound call to #{to_number}. Status: #{response.code}, Response: #{response.body}")
      raise "Failed to initiate outbound call: #{response.body}"
    end
  rescue => e
    Rails.logger.error("Error making outbound call to #{to_number}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end

  def book_discovery_call(customer)
    phone_number = customer.phone
    
    unless phone_number.present?
      Rails.logger.error("Customer #{customer.id} has no phone number")
      raise "Customer has no phone number"
    end
    
    Rails.logger.info("Initiating AI discovery call booking for customer #{customer.id} at #{phone_number}")
    
    result = make_outbound_call(phone_number)
    
    Rails.logger.info("AI discovery call initiated successfully for customer #{customer.id}")
    
    result
  rescue => e
    Rails.logger.error("Error booking discovery call for customer #{customer.id}: #{e.message}")
    raise e
  end

  def self.fetch_conversations
    new.fetch_conversations
  end

  def self.fetch_conversation_detail(conversation_id)
    new.fetch_conversation_detail(conversation_id)
  end

  def self.fetch_conversation_audio(conversation_id)
    new.fetch_conversation_audio(conversation_id)
  end

  def self.sync_conversations
    new_conversations = AiConversation.sync_from_api
    Rails.logger.info("Synced #{new_conversations.length} new AI conversations")
    new_conversations
  end

  def fetch_conversations
    uri = URI("#{@base_url}/convai/conversations")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request['xi-api-key'] = @api_key
    
    response = http.request(request)
    
    if response.code.to_i == 200
      response_data = JSON.parse(response.body)
      Rails.logger.info("Conversations API Response: #{response_data}")
      
      # Handle different response structures
      if response_data.is_a?(Array)
        response_data
      elsif response_data.is_a?(Hash) && response_data['conversations']
        response_data['conversations']
      else
        []
      end
    else
      Rails.logger.error("Failed to fetch conversations. Status: #{response.code}, Response: #{response.body}")
      raise "Failed to fetch conversations: #{response.body}"
    end
  rescue => e
    Rails.logger.error("Error fetching conversations: #{e.message}")
    raise e
  end

  def fetch_conversation_detail(conversation_id)
    uri = URI("#{@base_url}/convai/conversations/#{conversation_id}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request['xi-api-key'] = @api_key
    
    response = http.request(request)
    
    if response.code.to_i == 200
      JSON.parse(response.body)
    else
      Rails.logger.error("Failed to fetch conversation #{conversation_id}. Status: #{response.code}, Response: #{response.body}")
      raise "Failed to fetch conversation details: #{response.body}"
    end
  rescue => e
    Rails.logger.error("Error fetching conversation #{conversation_id}: #{e.message}")
    raise e
  end

  def fetch_conversation_audio(conversation_id)
    uri = URI("#{@base_url}/convai/conversations/#{conversation_id}/audio")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request['xi-api-key'] = @api_key
    
    response = http.request(request)
    
    if response.code.to_i == 200
      response.body
    else
      Rails.logger.error("Failed to fetch audio for conversation #{conversation_id}. Status: #{response.code}, Response: #{response.body}")
      nil
    end
  rescue => e
    Rails.logger.error("Error fetching audio for conversation #{conversation_id}: #{e.message}")
    nil
  end
end