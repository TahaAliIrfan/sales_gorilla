require 'net/http'
require 'uri'
require 'json'

module Whatsapp
  class ApiService
    attr_reader :instance_id, :api_token
    
    def initialize(instance_id = nil, api_token = nil)
      @device_id = 'TCDX'
      @api_token = api_token || Rails.application.credentials.dig(:TCDX_KEY)
      # @base_url = "https://nucleus.tecaudex.com/api/whatsapp"
      @instance_id = "7105323361"
      @api_token = "66ea6d5a06db48b5886a5a2ee08c8840721c794eec684e9e92"
      @base_url = "https://7105.api.greenapi.com/waInstance#{@instance_id}"
      @media_url = "https://7105.media.greenapi.com"
    end

    # Check if the API credentials are configured
    def credentials_configured?
      @api_token.present?
    end

    # Get all chats from WhatsApp instance
    def get_chats()
      response = get_request("chats?deviceId=#{@device_id}")
      handle_response(response)
    end

    def get_chat_room(chat_id)
      response = post_request("getChatHistory/#{@api_token}", { chatId: chat_id})
      handle_response(response)
    end

    def get_chat_media(chat_id, message_id)
      response = get_request("messages/#{chat_id}/#{message_id}/download?deviceId=#{@device_id}")
      handle_response(response)
    end


    def send_text_message(chat_id, content)
      response = post_request("sendMessage/#{@api_token}", { chatId: chat_id, message: content})
      handle_response(response)
    end

    def send_media_base64(chat_id, media_base64, filename, caption = nil, mime_type = nil)
      payload = {
        chatId: chat_id,
        mediaBase64: media_base64,
        filename: filename,
        deviceId: @device_id,
        mimeType: mime_type,
      }

      payload[:caption] = caption if caption.present?

      response = post_request("send-media", payload)
      handle_response(response)
    end


    def get_whatsapp_chat_id(phone_number)
      phone_without_plus = phone_number.gsub(/\A\+/, '')
      "#{phone_without_plus}@c.us"
    end

    def is_registered_on_whatsapp!(phone_number)
      cleaned_number = get_whatsapp_chat_id(phone_number)

      response = post_request("client/action/is-registered-user", {
        contactId: cleaned_number
      })

      response = handle_response(response)

      if response[:success]
        response[:data][:data][:isRegisteredUser]
      else
        false
      end
    end

    private
    
    def post_request(endpoint, params = {})
      uri = URI.parse("#{@base_url}/#{endpoint}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri)
      request["content-type"] = 'application/json'
      request.body = JSON.generate(params)


      http.request(request)
    end
    
    def get_request(endpoint)
      uri = URI.parse("#{@base_url}/#{endpoint}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request["accept"] = 'application/json'
      request['authorization'] = "Bearer #{@api_token}"

      http.request(request)
    end
    
    def handle_response(response)
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
      { success: false, error: "Failed to parse API response" }
    rescue StandardError => e
      Rails.logger.error("WhatsApp API Error: #{e.message}")
      { success: false, error: e.message }
    end
  end
end 