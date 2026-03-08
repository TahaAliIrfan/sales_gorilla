require 'securerandom'

class Api::V1::WhatsappController < Api::V1::BaseController
  def index
    begin
      # Get all customers for simplified access without authentication
      customers = Customer.all
      
      # Get all WhatsApp messages for customers
      messages = WhatsappMessage.joins(:customer)
                               .where(customer: customers)
                               .includes(:customer)
                               .order(created_at: :desc)
                               .limit(params[:limit]&.to_i || 100)
      
      formatted_messages = messages.map do |message|
        format_message_response(message, include_customer_info: true)
      end
      
      render_success(formatted_messages, "WhatsApp messages retrieved successfully")
    rescue => e
      Rails.logger.error "WhatsApp index error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render_error("Failed to retrieve WhatsApp messages: #{e.message}", nil, :internal_server_error)
    end
  end
  
  def show_customer_messages
    customer = Customer.find(params[:customer_id])
    
    # Get WhatsApp messages for specific customer
    messages = customer.whatsapp_messages
                      .order(created_at: :desc)
                      .limit(params[:limit]&.to_i || 100)
    
    formatted_messages = messages.map do |message|
      format_message_response(message)
    end
    
    render_success({
      customer: {
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        whatsapp_chat_id: customer.whatsapp_chat_id
      },
      messages: formatted_messages
    }, "Customer WhatsApp messages retrieved successfully")
  end
  
  def send_text_message
    customer = Customer.find(params[:customer_id])
    content = params[:content]&.strip
    
    if content.blank?
      return render_error("Message content cannot be empty", nil, :unprocessable_entity)
    end
    
    # Initialize WhatsApp API service
    whatsapp_service = Whatsapp::ApiService.new
    
    unless whatsapp_service.credentials_configured?
      return render_error("WhatsApp API credentials not configured", nil, :service_unavailable)
    end
    
    # Get or set WhatsApp chat ID for customer
    chat_id = get_or_set_chat_id(customer, whatsapp_service)
    
    unless chat_id
      return render_error("Could not determine WhatsApp chat ID for customer", nil, :unprocessable_entity)
    end
    
    # Send message via WhatsApp API
    result = whatsapp_service.send_text_message(chat_id, content)
    
    if result[:success]
      # Create WhatsApp message record
      message = customer.whatsapp_messages.create!(
        message_id: SecureRandom.uuid,
        body: content,
        direction: 'outbound',
        status: 'sent',
        timestamp: Time.current
      )
      
      render_success({
        message: {
          id: message.id,
          customer_id: message.customer_id,
          content: message.body,
          direction: message.direction,
          is_from_me: true,
          timestamp: message.timestamp
        }
      }, "Text message sent successfully")
    else
      render_error("Failed to send WhatsApp message: #{result[:error]}", nil, :service_unavailable)
    end
  end
  
  def send_image_message
    customer = Customer.find(params[:customer_id])
    
    # Handle file upload, base64 data, or URL
    if params[:file].present?
      # File upload case
      uploaded_file = params[:file]
      caption = params[:caption]&.strip

      # Validate file size (max 10MB as per CLAUDE.md)
      max_size = 10.megabytes
      if uploaded_file.size > max_size
        return render_error("File size too large. Maximum size allowed is 10MB.", nil, :unprocessable_entity)
      end

      begin
        # Read raw file data and send via WhatsApp API
        file_data = uploaded_file.read
        filename = uploaded_file.original_filename
        content_type = uploaded_file.content_type

        result = send_file_via_whatsapp(customer, file_data, filename, caption, content_type)

        if result[:success]
          render_success(result[:data], "Media file sent successfully")
        else
          render_error(result[:error], nil, :service_unavailable)
        end

      rescue => e
        Rails.logger.error "Media upload error: #{e.message}"
        render_error("Failed to process media file: #{e.message}", nil, :internal_server_error)
      end

    elsif params[:media_base64].present? && params[:filename].present?
      # Base64 data case (for API clients sending base64)
      media_base64 = params[:media_base64]&.strip
      filename = params[:filename]&.strip
      caption = params[:caption]&.strip

      if media_base64.blank? || filename.blank?
        return render_error("Both 'media_base64' and 'filename' are required", nil, :unprocessable_entity)
      end

      begin
        # Decode base64 to raw data
        file_data = Base64.strict_decode64(media_base64)
        content_type = determine_content_type_from_filename(filename)

        result = send_file_via_whatsapp(customer, file_data, filename, caption, content_type)

        if result[:success]
          render_success(result[:data], "Media message sent successfully")
        else
          render_error(result[:error], nil, :service_unavailable)
        end

      rescue => e
        Rails.logger.error "Base64 media error: #{e.message}"
        render_error("Failed to process base64 media: #{e.message}", nil, :internal_server_error)
      end
      
    elsif params[:media_url].present?
      # URL case (backward compatibility)
      media_url = params[:media_url]&.strip
      caption = params[:caption]&.strip
      filename = params[:filename]&.strip
      
      if media_url.blank?
        return render_error("Media URL cannot be empty", nil, :unprocessable_entity)
      end
      
      # Determine media type from URL
      media_info = determine_media_type_from_url(media_url)
      
      result = send_media_via_whatsapp(customer, media_url, caption, filename, media_info)
      
      if result[:success]
        render_success(result[:data], "Media message sent successfully")
      else
        render_error(result[:error], nil, :service_unavailable)
      end
      
    else
      render_error("Either 'file' (for upload), 'media_base64' + 'filename' (for base64), or 'media_url' parameter is required", nil, :unprocessable_entity)
    end
  end
  
  def sync_messages
    customer = Customer.find(params[:customer_id])
    
    # Initialize WhatsApp API service
    whatsapp_service = Whatsapp::ApiService.new
    
    unless whatsapp_service.credentials_configured?
      return render_error("WhatsApp API credentials not configured", nil, :service_unavailable)
    end
    
    # Get or set WhatsApp chat ID for customer
    chat_id = get_or_set_chat_id(customer, whatsapp_service)
    
    unless chat_id
      return render_error("Could not determine WhatsApp chat ID for customer", nil, :unprocessable_entity)
    end
    
    # Fetch messages from WhatsApp API
    result = whatsapp_service.get_chat_messages(chat_id, limit: params[:limit]&.to_i || 50)
    
    if result[:success] && result[:data]
      messages_data = result[:data]
      synced_count = 0
      
      messages_data.each do |msg_data|
        # Skip if message already exists
        next if customer.whatsapp_messages.exists?(message_id: msg_data[:id])
        
        customer.whatsapp_messages.create!(
          message_id: msg_data[:id],
          body: msg_data[:body] || msg_data[:caption] || "[#{msg_data[:type]}]",
          direction: msg_data[:fromMe] ? 'outbound' : 'inbound',
          status: 'received',
          timestamp: Time.at(msg_data[:timestamp]&.to_i || Time.current.to_i)
        )
        
        synced_count += 1
      end
      
      render_success({
        synced_count: synced_count,
        total_fetched: messages_data.size
      }, "Messages synced successfully")
    else
      render_error("Failed to sync WhatsApp messages: #{result[:error]}", nil, :service_unavailable)
    end
  end
  
  private
  
  def get_or_set_chat_id(customer, whatsapp_service)
    # Return existing chat ID if available
    return customer.whatsapp_chat_id if customer.whatsapp_chat_id.present?
    
    # Try to get chat ID from phone number
    if customer.phone.present?
      chat_id = whatsapp_service.get_chat_id_from_phone(customer.phone)
      
      if chat_id
        customer.update!(whatsapp_chat_id: chat_id)
        return chat_id
      end
    end
    
    nil
  end
  
  def valid_media_file?(file)
    return false unless file.respond_to?(:content_type) && file.respond_to?(:original_filename)
    
    content_type = file.content_type.to_s.downcase
    filename = file.original_filename.to_s.downcase
    
    # Image types
    image_types = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif']
    image_extensions = ['.jpg', '.jpeg', '.png', '.gif']
    
    # Video types
    video_types = ['video/mp4', 'video/3gpp', 'video/quicktime']
    video_extensions = ['.mp4', '.3gp', '.mov']
    
    # Audio types
    audio_types = ['audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/mp4']
    audio_extensions = ['.mp3', '.wav', '.ogg', '.m4a']
    
    # Document types
    document_types = ['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'text/plain', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']
    document_extensions = ['.pdf', '.doc', '.docx', '.txt', '.xlsx']
    
    all_types = image_types + video_types + audio_types + document_types
    all_extensions = image_extensions + video_extensions + audio_extensions + document_extensions
    
    all_types.include?(content_type) || all_extensions.any? { |ext| filename.end_with?(ext) }
  end
  
  def store_media_file(file)
    # Generate unique filename
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    random_id = SecureRandom.hex(8)
    extension = File.extname(file.original_filename)
    unique_filename = "whatsapp_media/#{timestamp}_#{random_id}#{extension}"
    
    # For WhatsApp media, we need publicly accessible URLs
    # Use S3 even in development for WhatsApp media uploads
    service_name = Rails.env.production? ? :amazon : :amazon
    
    # Upload using specified service
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file.tempfile,
      filename: unique_filename,
      content_type: file.content_type,
      service_name: service_name
    )
    
    # S3 URLs are globally accessible
    media_url = blob.url
    
    # Media info for storage
    media_info = {
      filename: file.original_filename,
      content_type: file.content_type,
      size: file.size,
      blob_id: blob.id,
      media_type: determine_media_type_from_content_type(file.content_type)
    }
    
    [media_url, media_info]
  end
  
  def determine_media_type_from_content_type(content_type)
    case content_type.to_s.downcase
    when /^image\//
      'image'
    when /^video\//
      'video'
    when /^audio\//
      'audio'
    when /^text\//, /application\/pdf/, /application\/msword/, /application\/vnd\./, /application\/zip/, /application\/x-rar/
      'document'
    else
      # Default to document for any unknown type
      'document'
    end
  end
  
  def determine_media_type_from_url(url)
    extension = File.extname(url.split('?').first).downcase
    
    case extension
    when '.jpg', '.jpeg', '.png', '.gif'
      { media_type: 'image' }
    when '.mp4', '.3gp', '.mov'
      { media_type: 'video' }
    when '.mp3', '.wav', '.ogg', '.m4a'
      { media_type: 'audio' }
    else
      { media_type: 'document' }
    end
  end
  
  def determine_content_type_from_filename(filename)
    extension = File.extname(filename).downcase
    
    case extension
    when '.jpg', '.jpeg'
      'image/jpeg'
    when '.png'
      'image/png'
    when '.gif'
      'image/gif'
    when '.mp4'
      'video/mp4'
    when '.3gp'
      'video/3gpp'
    when '.mov'
      'video/quicktime'
    when '.mp3'
      'audio/mpeg'
    when '.wav'
      'audio/wav'
    when '.ogg'
      'audio/ogg'
    when '.m4a'
      'audio/mp4'
    when '.pdf'
      'application/pdf'
    when '.doc'
      'application/msword'
    when '.docx'
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    when '.txt'
      'text/plain'
    when '.xlsx'
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    else
      'application/octet-stream'
    end
  end
  
  def format_message_response(message, include_customer_info: false)
    response = {
      id: message.id,
      customer_id: message.customer_id,
      message_id: message.message_id,
      content: message.body,
      direction: message.direction,
      is_from_me: message.direction == 'outbound',
      timestamp: message.timestamp,
      created_at: message.created_at
    }
    
    # Add customer info if requested
    if include_customer_info && message.customer
      response[:customer_name] = message.customer.name
      response[:customer_phone] = message.customer.phone
    end
    
    # Add media info if available
    if message.metadata.present? && message.metadata.is_a?(Hash)
      metadata = message.metadata.with_indifferent_access
      
      if metadata[:media_url].present?
        response[:media] = {
          url: metadata[:media_url],
          type: metadata[:media_type],
          filename: metadata[:filename],
          content_type: metadata[:content_type],
          size: metadata[:size]
        }.compact
        
        response[:has_media] = true
      end
    end
    
    response
  end
  
  def send_file_via_whatsapp(customer, file_data, filename, caption, content_type = nil)
    whatsapp_service = Whatsapp::ApiService.new

    unless whatsapp_service.credentials_configured?
      return { success: false, error: "WhatsApp API credentials not configured" }
    end

    chat_id = get_or_set_chat_id(customer, whatsapp_service)

    unless chat_id
      return { success: false, error: "Could not determine WhatsApp chat ID for customer" }
    end

    content_type ||= determine_content_type_from_filename(filename)
    media_type = determine_media_type_from_content_type(content_type)

    base64_data = Base64.strict_encode64(file_data)
    result = whatsapp_service.send_file(chat_id, base64_data, filename, caption, content_type)

    if result[:success]
      begin
        # Create Active Storage blob for local storage
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(file_data),
          filename: "whatsapp_media/#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(8)}_#{filename}",
          content_type: content_type
        )

        media_url = blob.url

        # Create WhatsApp message record
        message = customer.whatsapp_messages.create!(
          message_id: result[:data][:idMessage] || SecureRandom.uuid,
          body: caption || "[#{media_type.capitalize} sent]",
          direction: 'outbound',
          status: 'sent',
          timestamp: Time.current,
          metadata: {
            media_url: media_url,
            media_type: media_type,
            filename: filename,
            content_type: content_type,
            size: file_data.size,
            blob_id: blob.id
          }.compact
        )

        {
          success: true,
          data: {
            message: {
              id: message.id,
              customer_id: message.customer_id,
              content: message.body,
              direction: message.direction,
              is_from_me: true,
              timestamp: message.timestamp,
              media_url: media_url,
              media_type: media_type,
              filename: filename
            }
          }
        }
      rescue => e
        Rails.logger.error "Failed to create blob: #{e.message}"
        message = customer.whatsapp_messages.create!(
          message_id: result[:data][:idMessage] || SecureRandom.uuid,
          body: caption || "[Media sent]",
          direction: 'outbound',
          status: 'sent',
          timestamp: Time.current,
          metadata: { filename: filename, media_type: media_type }
        )

        {
          success: true,
          data: {
            message: {
              id: message.id,
              customer_id: message.customer_id,
              content: message.body,
              direction: message.direction,
              is_from_me: true,
              timestamp: message.timestamp,
              filename: filename
            }
          }
        }
      end
    else
      { success: false, error: "Failed to send WhatsApp media: #{result[:error]}" }
    end
  end

  def send_media_via_whatsapp(customer, media_url, caption, filename, media_info)
    whatsapp_service = Whatsapp::ApiService.new

    unless whatsapp_service.credentials_configured?
      return { success: false, error: "WhatsApp API credentials not configured" }
    end

    chat_id = get_or_set_chat_id(customer, whatsapp_service)

    unless chat_id
      return { success: false, error: "Could not determine WhatsApp chat ID for customer" }
    end

    file_data = download_file_from_url(media_url)
    unless file_data
      return { success: false, error: "Failed to download media from URL" }
    end

    content_type = media_info[:content_type] || determine_content_type_from_filename(filename)
    base64_data = Base64.strict_encode64(file_data)
    result = whatsapp_service.send_file(chat_id, base64_data, filename, caption, content_type)

    if result[:success]
      message = customer.whatsapp_messages.create!(
        message_id: SecureRandom.uuid,
        body: caption || "[#{media_info[:media_type].capitalize} sent]",
        direction: 'outbound',
        status: 'sent',
        timestamp: Time.current,
        metadata: {
          media_url: media_url,
          media_type: media_info[:media_type],
          filename: filename,
          content_type: content_type,
          size: file_data.bytesize,
          blob_id: media_info[:blob_id]
        }.compact
      )

      {
        success: true,
        data: {
          message: {
            id: message.id,
            customer_id: message.customer_id,
            content: message.body,
            direction: message.direction,
            is_from_me: true,
            timestamp: message.timestamp,
            media_url: media_url,
            media_type: media_info[:media_type],
            filename: filename
          }
        }
      }
    else
      { success: false, error: "Failed to send WhatsApp media: #{result[:error]}" }
    end
  end
  
  def download_file_from_url(url)
    uri = URI.parse(url)
    response = Net::HTTP.get_response(uri)
    return nil unless response.is_a?(Net::HTTPSuccess)

    response.body.force_encoding('BINARY')
  rescue StandardError => e
    Rails.logger.error("Failed to download file from #{url}: #{e.message}")
    nil
  end

  def status
    begin
      # Simple status endpoint
      render_success({ status: 'active', service: 'whatsapp' }, "WhatsApp service is running")
    rescue => e
      Rails.logger.error "WhatsApp status error: #{e.message}"
      render_error("WhatsApp service status unavailable: #{e.message}", nil, :service_unavailable)
    end
  end
end