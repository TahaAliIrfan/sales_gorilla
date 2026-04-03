require 'net/http'
require 'uri'
require 'json'

module Whatsapp
  class ApiService
    attr_reader :instance_id, :api_token
    
    def initialize(instance_id = nil, api_token = nil)
      @URL = "https://whatsapp.tecaudex.com"
    end

    # Check if the API credentials are configured
    def credentials_configured?
      true
    end

    # Get all chats from WhatsApp instance
    def get_chats()
      response = get_request("#{@URL}/api/chats")
      handle_response(response)
    end

    def get_chat_room(chat_id)
      response = get_request("#{@URL}/api/chat/number/#{chat_id}")
      handle_response(response)
    end

    def send_text_message(chat_id, content)
      response = post_request("#{@URL}/api/send", { number: chat_id, message: content})
      handle_response(response)
    end

    def send_file(chat_id, base64_data, filename, caption = nil, mime_type = nil)
      response = post_request("#{@URL}/api/send/media", {
        number: chat_id,
        media: base64_data,
        filename: filename,
        caption: caption
      }.compact)
      handle_response(response)
    end


    def get_whatsapp_chat_id(phone_number)
      phone_without_plus = phone_number.gsub(/\A\+/, '')
      "#{phone_without_plus}@c.us"
    end

    private
    
    def post_request(endpoint, params = {})
      uri = URI.parse("#{endpoint}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri)
      request["content-type"] = 'application/json'
      request.body = JSON.generate(params)


      http.request(request)
    end

    
    def get_request(endpoint)
      uri = URI.parse("#{endpoint}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request["accept"] = 'application/json'
      request['authorization'] = "Bearer #{@api_token}"

      http.request(request)
    end
    
    def handle_response(response)
      Rails.logger.info("WhatsApp API Response Code: #{response.code}")
      Rails.logger.info("WhatsApp API Response Body: #{response.body[0, 500]}") if response.body.present?

      parsed_response = JSON.parse(response.body, symbolize_names: true)

      if response.code.to_i == 200
        { success: true, data: parsed_response }
      else
        error_message = parsed_response[:message] || "Unknown error occurred"
        Rails.logger.error("WhatsApp API Error: #{error_message}")
        { success: false, error: error_message }
      end
    rescue JSON::ParserError => e
      Rails.logger.error("WhatsApp API JSON Parse Error: #{e.message}")
      Rails.logger.error("WhatsApp API Raw Response: #{response.body[0, 1000]}") if response.body.present?
      { success: false, error: "Failed to parse API response" }
    rescue StandardError => e
      Rails.logger.error("WhatsApp API Error: #{e.message}")
      { success: false, error: e.message }
    end
  end
end 