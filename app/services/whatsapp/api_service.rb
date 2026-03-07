require 'net/http'
require 'uri'
require 'json'

module Whatsapp
  class ApiService
    attr_reader :instance_id, :api_token
    
    def initialize(instance_id = nil, api_token = nil)
      @device_id = 'TCDX'
      @api_token = api_token || Rails.application.credentials.dig(:TCDX_KEY)
      @instance_id = Rails.application.credentials.dig(:GREEN_INSTANCE_ID)
      @api_token = Rails.application.credentials.dig(:GREEN_AUTH_TOKEN)
      @base_url = "https://7105.api.greenapi.com/waInstance#{@instance_id}"
      @media_url = "https://7105.media.greenapi.com"
      @URL = "https://whatsapp.tecaudex.com"
    end

    # Check if the API credentials are configured
    def credentials_configured?
      @api_token.present?
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

    def get_chat_media(chat_id, message_id)
      response = get_request("messages/#{chat_id}/#{message_id}/download?deviceId=#{@device_id}")
      handle_response(response)
    end


    def send_text_message(chat_id, content)
      response = post_request("sendMessage/#{@api_token}", { chatId: chat_id, message: content})
      handle_response(response)
    end

    def send_file(chat_id, file_data, filename, caption = nil, mime_type = nil)
      response = post_multipart_request(
        "waInstance#{@instance_id}/sendFileByUpload/#{@api_token}",
        chat_id: chat_id,
        file_data: file_data,
        filename: filename,
        caption: caption,
        mime_type: mime_type
      )
      handle_response(response)
    end

    # Alias for backwards compatibility
    alias_method :send_media_base64, :send_file


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

    def post_multipart_request(endpoint, chat_id:, file_data:, filename:, caption: nil, mime_type: nil)
      uri = URI.parse("#{@media_url}/#{endpoint}")

      boundary = "----WebKitFormBoundary#{SecureRandom.hex(16)}"
      content_type = mime_type || 'application/octet-stream'

      # Build multipart body with consistent binary encoding
      body = "".dup.force_encoding('BINARY')

      # Add chatId field
      body << "--#{boundary}\r\n".force_encoding('BINARY')
      body << "Content-Disposition: form-data; name=\"chatId\"\r\n\r\n".force_encoding('BINARY')
      body << "#{chat_id}\r\n".force_encoding('BINARY')

      # Add caption field if present
      if caption.present?
        body << "--#{boundary}\r\n".force_encoding('BINARY')
        body << "Content-Disposition: form-data; name=\"caption\"\r\n\r\n".force_encoding('BINARY')
        body << caption.to_s.encode('UTF-8').force_encoding('BINARY')
        body << "\r\n".force_encoding('BINARY')
      end

      # Add fileName field
      body << "--#{boundary}\r\n".force_encoding('BINARY')
      body << "Content-Disposition: form-data; name=\"fileName\"\r\n\r\n".force_encoding('BINARY')
      body << "#{filename}\r\n".force_encoding('BINARY')

      # Add file field
      body << "--#{boundary}\r\n".force_encoding('BINARY')
      body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n".force_encoding('BINARY')
      body << "Content-Type: #{content_type}\r\n\r\n".force_encoding('BINARY')
      body << file_data.force_encoding('BINARY')
      body << "\r\n".force_encoding('BINARY')

      # Close boundary
      body << "--#{boundary}--\r\n".force_encoding('BINARY')

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
      request.body = body

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