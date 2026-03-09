require 'base64'
require 'stringio'

class WhatsappMessageService
  attr_reader :api_service

  def initialize
    @api_service = Whatsapp::ApiService.new
  end

  def get_chat_lists
    return { success: false, error: "WhatsApp API not configured" } unless @api_service.credentials_configured?

    begin
      response = @api_service.get_chats
      return { success: false, error: response[:error] } unless response[:success]

      return { success: true, chats: response[:data] }

    rescue StandardError => e
      Rails.logger.error("WhatsappMessageService Error: #{e.message}")
      { success: false, error: e.message }
    end

  end

  def fetch_and_store_messages(whatsapp_chat_id, customer = nil)
    return { success: false, error: "WhatsApp API not configured" } unless @api_service.credentials_configured?

    begin
      response = @api_service.get_chat_room(whatsapp_chat_id)
      return { success: false, error: response[:error] } unless response[:success]

      messages_data = response[:data][:messages] || []
      stored_messages = []

      messages_data.each do |message|

        message_id = message[:id]
        next if Message.exists?(message_id: message_id)

        direction = message[:fromMe] == true ? 'outbound' : 'inbound'
        processed_message = process_message(message, customer, direction)
        stored_messages << processed_message if processed_message
      end

      { success: true, messages_count: stored_messages.count, messages: stored_messages }

    rescue StandardError => e
      Rails.logger.error("WhatsappMessageService Error: #{e.message}")
      { success: false, error: e.message }
    end
  end

  def fetch_all_chats_and_associate_customers
    return { success: false, error: "WhatsApp API not configured" } unless @api_service.credentials_configured?

    begin
      # Fetch all chats from WhatsApp API
      response = @api_service.get_all_chats
      return { success: false, error: response[:error] } unless response[:success]

      chats_data = response[:data] || []
      associations_made = 0
      new_chat_ids = []

      chats_data.each do |chat|
        chat_id = chat[:id]
        phone_number = extract_phone_from_chat_id(chat_id)
        
        next unless phone_number

        # Try to find customer by phone number
        customer = find_customer_by_phone(phone_number)
        
        if customer && customer.whatsapp_chat_id.blank?
          customer.update(whatsapp_chat_id: chat_id)
          associations_made += 1
          new_chat_ids << chat_id
          Rails.logger.info("Associated chat ID #{chat_id} with customer #{customer.id} (#{customer.name})")
        end
      end

      { 
        success: true, 
        total_chats: chats_data.count,
        associations_made: associations_made,
        new_chat_ids: new_chat_ids
      }

    rescue StandardError => e
      Rails.logger.error("WhatsappMessageService fetch_all_chats_and_associate_customers Error: #{e.message}")
      { success: false, error: e.message }
    end
  end

  def send_message(whatsapp_chat_id, message_content, customer = nil)
    return { success: false, error: "WhatsApp API not configured" } unless @api_service.credentials_configured?
    return { success: false, error: "Message content cannot be blank" } if message_content.blank?
    return { success: false, error: "WhatsApp chat ID cannot be blank" } if whatsapp_chat_id.blank?

    begin
      response = @api_service.send_text_message(whatsapp_chat_id, message_content)

      if response[:success]
        message_id = response[:data][:idMessage]
        timestamp = Time.now

        # Base message attributes
        message_attrs = {
          message_id: message_id,
          customer: customer,
          direction: 'outbound',
          status: 'delivered',
          message_type: 'text',
          content: message_content,
          whatsapp_chat_id: whatsapp_chat_id,
          created_at: timestamp,
          updated_at: timestamp,
        }


        message = Message.new(message_attrs)

        if message.save
          {
            success: true,
            message: "message sent successfully",
          }
        else
          {
            success: false,
            error: "Unable to save message: #{message.errors.full_messages.join(', ')}",
            message_data: response[:data]
          }
        end

        Rails.logger.info("Successfully sent WhatsApp message to #{whatsapp_chat_id}")
        {
          success: true,
          message: "Message sent successfully",
          message_data: response[:data]
        }
      else
        Rails.logger.error("Failed to send WhatsApp message: #{response[:error]}")
        { success: false, error: response[:error] || "Failed to send message" }
      end

    rescue StandardError => e
      Rails.logger.error("WhatsappMessageService send_message error: #{e.message}")
      { success: false, error: e.message }
    end
  end

  def send_media_message(whatsapp_chat_id, file_data, filename, caption = nil, customer = nil)
    return { success: false, error: "WhatsApp API not configured" } unless @api_service.credentials_configured?
    return { success: false, error: "File data cannot be blank" } if file_data.blank?
    return { success: false, error: "Filename cannot be blank" } if filename.blank?
    return { success: false, error: "WhatsApp chat ID cannot be blank" } if whatsapp_chat_id.blank?

    begin
      # Ensure we have raw binary data
      raw_data = file_data.is_a?(String) ? file_data.dup.force_encoding('BINARY') : file_data

      # Detect format from raw bytes
      format_info = detect_format_from_bytes(raw_data)

      # Base64-encode for the API
      base64_data = Base64.strict_encode64(raw_data)

      response = @api_service.send_file(whatsapp_chat_id, base64_data, filename, caption, format_info[:content_type])

      if response[:success]
        message_id = response[:data][:idMessage]
        chat_id = response[:data][:chatId] || whatsapp_chat_id
        timestamp = Time.current

        # Base message attributes
        message_attrs = {
          message_id: message_id,
          customer: customer,
          direction: 'outbound',
          status: 'delivered',
          message_type: format_info[:type],
          content: caption.present? ? caption : filename,
          whatsapp_chat_id: chat_id,
          created_at: timestamp,
          updated_at: timestamp,
        }

        message = Message.new(message_attrs)

        if message.save
          attachment_success = attach_file_to_message(raw_data, filename, format_info[:content_type], message)
          {
            success: true,
            message: "Media message sent successfully",
          }
        else
          {
            success: false,
            error: "Unable to save message: #{message.errors.full_messages.join(', ')}",
            message_data: response[:data]
          }
        end

      else
        Rails.logger.error("Failed to send WhatsApp media message: #{response[:error]}")
        { success: false, error: response[:error] || "Failed to send media message" }
      end

    rescue StandardError => e
      Rails.logger.error("WhatsappMessageService send_media_message error: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
      { success: false, error: e.message }
    end
  end

  private

  def process_message(message, customer, direction)

    message_type = message[:type]
    message_id = message[:id]
    timestamp = Time.at(message[:timestamp])

    # Base message attributes
    message_attrs = {
      message_id: message_id,
      customer: customer,
      direction: direction,
      message_type: message_type,
      created_at: timestamp,
      updated_at: timestamp,
    }

    if message_type == 'chat' or message_type == 'e2e_notification'
      if message[:body] == ''
        message_attrs[:content] = 'Unable To Read Message'
      else
        message_attrs[:content] = message[:body]
      end
      created_message = create_message(message_attrs)
    else
      raw_data = decode_base64_data(message[:media][:data])
      message_attrs[:message_type] = message[:type]
      message_attrs[:content] = "Content"

      created_message = create_message(message_attrs)

      filename = message_id
      attach_file_to_message(raw_data, filename, message[:media][:mimetype], created_message)
    end

    created_message
  end

  def create_message(message_attrs)
    message = Message.create!(message_attrs)
    Rails.logger.info("Created message: #{message.message_id} for customer: #{message.customer_id}")
    message
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to create message: #{e.message}")
    nil
  end

  def extract_phone_from_chat_id(chat_id)
    # WhatsApp chat IDs are typically in format: phone_number@c.us
    # Extract the phone number part
    return nil unless chat_id.present?
    
    # Remove @c.us suffix if present
    phone = chat_id.gsub(/@c\.us$/, '')
    
    # Basic validation - should be numeric and reasonable length
    return nil unless phone.match?(/^\d{10,15}$/)
    
    phone
  end

  def find_customer_by_phone(phone_number)
    return nil unless phone_number.present?
    
    # Try exact match first
    customer = Customer.find_by(phone: phone_number)
    return customer if customer
    
    # Try with different formatting (with +, without +, etc.)
    formatted_variations = [
      "+#{phone_number}",
      "#{phone_number}",
      phone_number.gsub(/^\+/, ''),
      phone_number.gsub(/\D/, '') # Remove all non-digits
    ]
    
    formatted_variations.each do |variation|
      customer = Customer.find_by(phone: variation)
      return customer if customer
    end
    
    # Try partial matches (last 10 digits)
    if phone_number.length > 10
      last_10 = phone_number.last(10)
      Customer.where("phone LIKE ?", "%#{last_10}").first
    else
      nil
    end
  end

  def decode_base64_data(data)
    return nil if data.blank?

    Base64.decode64(data).force_encoding('BINARY')
  rescue ArgumentError => e
    Rails.logger.error("Failed to decode Base64 data: #{e.message}")
    nil
  end

  def detect_format_from_bytes(raw_data)
    return { type: 'document', content_type: 'application/octet-stream' } if raw_data.blank?

    # Read first 8 bytes to check magic numbers
    hex = raw_data.bytes.first(8).map { |b| b.to_s(16).rjust(2, '0') }.join.upcase

    case hex
    when /^FFD8FF/
      { type: 'image', content_type: 'image/jpeg' }
    when /^89504E47/
      { type: 'image', content_type: 'image/png' }
    when /^47494638/
      { type: 'image', content_type: 'image/gif' }
    when /^25504446/
      { type: 'document', content_type: 'application/pdf' }
    when /^504B0304/
      { type: 'document', content_type: 'application/zip' }
    when /^00000.*66747970/
      { type: 'video', content_type: 'video/mp4' }
    when /^494433/, /^FFFB/, /^FFF3/
      { type: 'audio', content_type: 'audio/mpeg' }
    else
      { type: 'document', content_type: 'application/octet-stream' }
    end
  end

  def attach_file_to_message(file_data, filename, content_type, message)

    return false if file_data.blank? || message.nil?

    begin
      message.document.attach(
        io: StringIO.new(file_data),
        filename: filename,
        content_type: content_type
      )
      true
    rescue => e
      Rails.logger.error("Failed to attach file to message: #{e.message}")
      false
    end
  end
end