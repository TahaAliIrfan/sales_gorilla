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

        message_id = message[:id]
        next if Message.exists?(message_id: message_id)

        direction = message[:fromMe] ? 'outbound' : 'inbound'
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

        message_id = response[:data][:id]
        whatsapp_chat_id = response[:data][:chatId]
        timestamp = Time.at(response[:data][:timestamp])

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
    message_type = determine_message_type(message[:type])
    message_id = message[:id]
    whatsapp_chat_id = message[:chatId]
    timestamp = Time.at(message[:timestamp])
    status = message[:status]

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
      if message[:content] == ''
        message_attrs[:content] = 'deleted message'
      else
        message_attrs[:content] = message[:content]
      end
    else
      message_attrs[:content] = message_type
    end

    created_message = create_message(message_attrs)

    if created_message && message_type != 'text'
      media = @api_service.get_chat_media(message[:chatId], message[:id])

      return unless media[:success]

      if is_base64?(media[:data][:mediaBase64])
        attach_base64_to_message(media[:data][:mediaBase64], created_message)
      else
        return
      end
    end

    created_message
  end

  def extract_content_name(message, message_type)
    message.dig(:_data, :filename) ||
      message.dig(:_data, :caption) ||
      message[:body] ||
      "#{message_type.capitalize} message"
  end

  def has_base64_data?(data)
    return false unless data.is_a?(String) && data.length > 50

    # Check for common base64 signatures
    data.start_with?('/9j/') || # JPEG
      data.start_with?('iVBORw') || # PNG
      data.start_with?('R0lGODlh') || # GIF
      data.start_with?('UklGR') || # WebP
      data.start_with?('JVBERi') || # PDF
      data.start_with?('UEsD') || # Office/ZIP
      data.match?(/^[A-Za-z0-9+\/]{100,}={0,2}$/) # Generic base64
  end

  def attach_base64_to_message(base64_data, message)
    begin
      decoded_data = Base64.decode64(base64_data)
      format_info = detect_format(base64_data)

      timestamp = message.created_at.strftime('%Y%m%d_%H%M%S')
      filename = "whatsapp_#{format_info[:type]}_#{timestamp}.#{format_info[:extension]}"

      file_io = StringIO.new(decoded_data)

      message.document.attach(
        io: file_io,
        filename: filename,
        content_type: format_info[:content_type]
      )

      Rails.logger.info("Attached #{format_info[:format]} to message #{message.message_id}")
      true

    rescue StandardError => e
      Rails.logger.error("Error attaching base64 to message: #{e.message}")
      false
    end
  end

  def detect_format(base64_string)
    case base64_string[0..20]
    when /^\/9j\//
      { format: 'JPEG', type: 'image', extension: 'jpg', content_type: 'image/jpeg' }
    when /^iVBORw/
      { format: 'PNG', type: 'image', extension: 'png', content_type: 'image/png' }
    when /^R0lGODlh/
      { format: 'GIF', type: 'image', extension: 'gif', content_type: 'image/gif' }
    when /^UklGR/
      { format: 'WebP', type: 'image', extension: 'webp', content_type: 'image/webp' }
    when /^JVBERi/
      { format: 'PDF', type: 'document', extension: 'pdf', content_type: 'application/pdf' }
    when /^UEsD/
      detect_office_format(base64_string)
    when /^SUQz/, /^\/\/[Oo]/, /^ID3/
      { format: 'MP3', type: 'audio', extension: 'mp3', content_type: 'audio/mpeg' }
    when /^ZlJB/
      { format: 'FLAC', type: 'audio', extension: 'flac', content_type: 'audio/flac' }
    when /^T2dn/
      { format: 'OGG', type: 'audio', extension: 'ogg', content_type: 'audio/ogg' }
    when /^Zm10eQ==/
      { format: 'MP4', type: 'video', extension: 'mp4', content_type: 'video/mp4' }
    when /^AAAAIGZ0eXA=/
      { format: 'MOV', type: 'video', extension: 'mov', content_type: 'video/quicktime' }
    when /^UklGR.*WEBP/
      { format: 'WebM', type: 'video', extension: 'webm', content_type: 'video/webm' }
    else
      detect_text_format(base64_string)
    end
  end

  def detect_office_format(base64_string)
    decoded_sample = Base64.decode64(base64_string[0..100])
    
    if decoded_sample.include?('xl/')
      { format: 'Excel', type: 'document', extension: 'xlsx', content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }
    elsif decoded_sample.include?('ppt/')
      { format: 'PowerPoint', type: 'document', extension: 'pptx', content_type: 'application/vnd.openxmlformats-officedocument.presentationml.presentation' }
    elsif decoded_sample.include?('word/')
      { format: 'Word', type: 'document', extension: 'docx', content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' }
    else
      { format: 'ZIP', type: 'document', extension: 'zip', content_type: 'application/zip' }
    end
  end

  def detect_text_format(base64_string)
    begin
      decoded_sample = Base64.decode64(base64_string[0..200])
      
      if decoded_sample.ascii_only? && decoded_sample.include?(',')
        { format: 'CSV', type: 'document', extension: 'csv', content_type: 'text/csv' }
      elsif decoded_sample.ascii_only? && decoded_sample.include?("\t")
        { format: 'TSV', type: 'document', extension: 'tsv', content_type: 'text/tab-separated-values' }
      elsif decoded_sample.start_with?('<?xml')
        { format: 'XML', type: 'document', extension: 'xml', content_type: 'application/xml' }
      elsif decoded_sample.start_with?('{') || decoded_sample.start_with?('[')
        { format: 'JSON', type: 'document', extension: 'json', content_type: 'application/json' }
      elsif decoded_sample.ascii_only?
        { format: 'Text', type: 'document', extension: 'txt', content_type: 'text/plain' }
      else
        { format: 'Unknown', type: 'document', extension: 'bin', content_type: 'application/octet-stream' }
      end
    rescue
      { format: 'Unknown', type: 'document', extension: 'bin', content_type: 'application/octet-stream' }
    end
  end

  def determine_message_type(whatsapp_type)
    case whatsapp_type&.downcase
    when 'chat' then 'text'
    when 'document' then 'document'
    when 'image' then 'image'
    when 'audio', 'ptt' then 'audio'
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

  def is_base64?(string)
    return false unless string.is_a?(String)
    return false if string.length < 4

    # Check if string contains only valid base64 characters
    string.match?(/\A[A-Za-z0-9+\/]*={0,2}\z/) && string.length % 4 == 0
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