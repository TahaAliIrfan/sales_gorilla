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

      messages_data = response[:data] || []
      stored_messages = []

      messages_data.each do |message|

        message_id = message[:idMessage]
        next if Message.exists?(message_id: message_id)

        direction = message[:type] == 'outgoing' ? 'outbound' : 'inbound'
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
      # Convert file data to base64 if it's not already
      base64_data = if file_data.is_a?(String) && is_base64?(file_data)
                      file_data
                    else
                      Base64.strict_encode64(file_data)
                    end

      mine_type = detect_format(base64_data)

      # Send media message via WhatsApp API using send_media_base64 method
      response = @api_service.send_media_base64(whatsapp_chat_id, base64_data, filename, caption, mine_type[:content_type])

      if response[:success]

        message_type = detect_format(base64_data)
        message_id = response[:data][:id]
        whatsapp_chat_id = response[:data][:chatId]
        timestamp = Time.at(response[:data][:timestamp])

        # Base message attributes
        message_attrs = {
          message_id: message_id,
          customer: customer,
          direction: 'outbound',
          status: 'delivered',
          message_type: message_type[:type],
          content: caption.present? ? caption : filename,
          whatsapp_chat_id: whatsapp_chat_id,
          created_at: timestamp,
          updated_at: timestamp,
        }

        message = Message.new(message_attrs)

        if message.save
          attachment_success = attach_base64_to_message(base64_data, message)
          if attachment_success
            {
              success: true,
              message: "Media message sent successfully",
            }
          else
            {
              success: false,
              error: "Failed to attach media file to message",
              message_data: response[:data]
            }
          end
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
      { success: false, error: e.message }
    end
  end

  private

  def process_message(message, customer, direction)
    message_type = determine_message_type(message[:typeMessage])
    message_id = message[:idMessage]
    whatsapp_chat_id = message[:chatId]
    timestamp = Time.at(message[:timestamp])
    if message[:statusMessage].present?
      status = message[:statusMessage]
    else
      status = 'read'
    end

    # Base message attributes
    message_attrs = {
      message_id: message_id,
      customer: customer,
      direction: direction,
      message_type: message_type,
      status: status,
      whatsapp_chat_id: whatsapp_chat_id,
      created_at: timestamp,
      updated_at: timestamp,
    }

    if message_type == 'text'
      message_attrs[:content] = message[:textMessage]
    else
      message_attrs[:content] = message[:downloadUrl]
    end


    created_message = create_message(message_attrs)

    created_message
  end

  def extract_content_name(message, message_type)
    message.dig(:_data, :filename) ||
      message.dig(:_data, :caption) ||
      message[:body] ||
      "#{message_type.capitalize} message"
  end

  def determine_message_type(whatsapp_type)
    case whatsapp_type
    when 'extendedTextMessage' then 'text'
    when 'documentMessage' then 'document'
    when 'imageMessage' then 'image'
    when 'audioMessage' then 'audio'
    when 'video' then 'video'
    when 'location' then 'location'
    when 'contact' then 'contact'
    else 'text'
    end
  end

  def determine_message_status(ack_status, direction)
    return 'delivered' if direction == 'inbound'

    case ack_status
    when 0 then 'pending'
    when 1 then 'sent'
    when 2 then 'delivered'
    when 3 then 'read'
    else 'sent'
    end
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
end