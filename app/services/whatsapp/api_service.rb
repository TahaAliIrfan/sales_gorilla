require 'net/http'
require 'uri'
require 'json'

module Whatsapp
  class ApiService
    attr_reader :instance_id, :api_token
    
    def initialize(instance_id = nil, api_token = nil)
      @instance_id = instance_id || Rails.application.credentials.dig(:WAAPI_INSTANCE_ID)
      @api_token = api_token || Rails.application.credentials.dig(:WAAPI_AUTH_TOKEN)
      @base_url = "https://waapi.app/api/v1/instances/#{@instance_id}"
    end
    
    # Check if the API credentials are configured
    def credentials_configured?
      @instance_id.present? && @api_token.present?
    end
    
    # Get client status (connected/disconnected)
    def get_client_status
      response = get_request("client/status")
      handle_response(response)
    end
    
    # Get all chats from WhatsApp instance
    def get_chats()
      response = post_request("client/action/get-chats")

      handle_response(response)
    end
    
    # Get messages for a specific chat
    def get_chat_messages(chat_id, limit: 50)
      response = post_request("message/action/fetch-messages", {
        chatId: chat_id,
        limit: limit
      })
      
      handle_response(response)
    end
    
    # Send text message
    def send_text_message(chat_id, content)
      response = post_request("message/action/send-text", {
        chatId: chat_id,
        text: content
      })
      
      handle_response(response)
    end
    
    # Send media message
    def send_media_message(chat_id, media_url, caption = nil, media_type = 'image')
      # Media type can be 'image', 'video', 'audio', 'document'
      endpoint = "message/action/send-#{media_type}"
      
      payload = {
        chatId: chat_id,
        url: media_url
      }
      
      # Add caption if provided
      payload[:caption] = caption if caption.present?
      
      response = post_request(endpoint, payload)
      handle_response(response)
    end
    
    # Mark messages as seen
    def mark_messages_as_seen(chat_id)
      response = post_request("chat/action/mark-as-seen", {
        chatId: chat_id
      })
      
      handle_response(response)
    end
    
    # Get chat details by ID
    def get_chat_by_id(chat_id)
      response = post_request("chat/action/get-chat-by-id", {
        chatId: chat_id
      })
      
      handle_response(response)
    end
    
    # Convert a phone number to WhatsApp chat ID
    def get_chat_id_from_phone(phone_number)
      # Remove any non-digit characters except the + sign
      cleaned_number = phone_number.gsub(/[^\d+]/, '')
      
      # Make sure the number starts with +
      cleaned_number = "+#{cleaned_number}" unless cleaned_number.start_with?('+')
      
      response = post_request("number/action/get-whatsapp-id", {
        phone: cleaned_number
      })
      
      result = handle_response(response)
      result[:data][:chatId] if result[:success]
    end
    
    # Check if a number is registered on WhatsApp
    def is_registered_on_whatsapp(phone_number)
      # Remove any non-digit characters except the + sign
      cleaned_number = phone_number.gsub(/[^\d+]/, '')
      
      # Make sure the number starts with +
      cleaned_number = "+#{cleaned_number}" unless cleaned_number.start_with?('+')
      
      response = post_request("contact/action/is-registered-user", {
        phone: cleaned_number
      })
      
      result = handle_response(response)
      result[:data][:isRegistered] if result[:success]
    end
    
    # Send typing state to a chat
    def send_typing(chat_id)
      response = post_request("chat/action/send-typing", {
        chatId: chat_id
      })
      
      handle_response(response)
    end
    
    # Stop typing indicator
    def stop_typing(chat_id)
      response = post_request("chat/action/stop-typing", {
        chatId: chat_id
      })
      
      handle_response(response)
    end
    
    private
    
    def post_request(endpoint, params = {})
      uri = URI.parse("#{@base_url}/#{endpoint}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri)
      request["accept"] = 'application/json'
      request["content-type"] = 'application/json'
      request['authorization'] = "Bearer #{@api_token}"
      request.body = params.to_json

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
        { success: true, data: parsed_response[:data] }
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