class ElevenLabsService
  def initialize
    @api_key = Rails.application.credentials.dig(:eleven_labs_api_key)
    @agent_id = Rails.application.credentials.dig(:eleven_labs_agent_id)
    @agent_phone_number_id = Rails.application.credentials.dig(:eleven_labs_agent_phone_number_id)
    
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
end