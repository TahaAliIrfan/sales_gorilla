class MessagesController < ApplicationController
  layout 'dashboard'
  before_action :require_login, except: :webhook
  before_action :set_customer, only: [:index, :create, :sync, :refresh]
  skip_before_action :verify_authenticity_token, only: [:webhook, :sync]
  after_action :verify_authorized, except: :webhook

  def index
    authorize @customer, :show?

    # Only fetch new messages if customer has a WhatsApp chat ID
    if @customer.whatsapp_chat_id.present?
      WhatsappMessageService.new.fetch_and_store_messages(@customer.whatsapp_chat_id, @customer)
    end
    
    @messages = @customer.messages
                        .includes(document_attachment: :blob)
                        .order(:created_at)
    
    respond_to do |format|
      format.json do
        Rails.logger.info("Messages API called for customer #{@customer.id} (#{@customer.name})")
        Rails.logger.info("Found #{@messages.count} messages")
        
        render json: {
          messages: @messages.map do |message|
            {
              id: message.id,
              content: message.content,
              direction: message.direction,
              message_type: message.message_type,
              status: message.status,
              created_at: message.created_at.iso8601,
              formatted_time: message.created_at.strftime('%H:%M'),
              has_attachment: message.document.attached?,
              attachment_url: message.document.attached? ? url_for(message.document) : nil,
              attachment_filename: message.document.attached? ? message.document.filename.to_s : nil
            }
          end
        }
      end
    end
  end

  def create
    authorize @customer, :show?
    
    whatsapp_service = WhatsappMessageService.new
    
    # Check if this is a media message (file upload) or text message
    if params[:file].present?
      # Handle file upload
      file = params[:file]
      caption = params[:caption]
      
      # Validate file
      validation_result = validate_file_with_details(file)
      unless validation_result[:valid]
        render json: { success: false, error: validation_result[:error] }, status: :unprocessable_entity
        return
      end
      
      # Read file data
      file_data = file.read
      filename = file.original_filename
      
      result = whatsapp_service.send_media_message(@customer.whatsapp_chat_id, file_data, filename, caption, @customer)
    else
      # Handle text message
      message_content = params[:message]&.dig(:content) || params[:content]
      
      if message_content.blank?
        render json: { success: false, error: 'Message content cannot be blank' }, status: :unprocessable_entity
        return
      end
      
      result = whatsapp_service.send_message(@customer.whatsapp_chat_id, message_content, @customer)
    end
    
    if result[:success]
      UserKpiRecord.track!(current_user&.id, :whatsapp_messages_sent)
      render json: { 
        success: true, 
        message: result[:message] || 'Message sent successfully',
        sent_message: result[:message_data]
      }
    else
      render json: { 
        success: false, 
        error: result[:error] || 'Failed to send message' 
      }, status: :unprocessable_entity
    end
  end

  def sync
    authorize @customer, :show?
    
    if @customer.whatsapp_chat_id.blank?
      respond_to do |format|
        format.html { redirect_to @customer, alert: 'Customer does not have a WhatsApp chat ID.' }
        format.json { render json: { success: false, error: 'Customer does not have a WhatsApp chat ID.' }, status: :unprocessable_entity }
      end
      return
    end
    
    begin
      whatsapp_service = WhatsappMessageService.new
      result = whatsapp_service.fetch_and_store_messages(@customer.whatsapp_chat_id, @customer)
      
      if result[:success]
        respond_to do |format|
          format.html { redirect_to @customer, notice: "Successfully synced #{result[:messages_count]} WhatsApp messages." }
          format.json { render json: { success: true, messages_count: result[:messages_count] } }
        end
      else
        respond_to do |format|
          format.html { redirect_to @customer, alert: "Failed to sync messages: #{result[:error]}" }
          format.json { render json: { success: false, error: result[:error] }, status: :unprocessable_entity }
        end
      end
    rescue => e
      Rails.logger.error("Failed to sync WhatsApp messages for customer #{@customer.id}: #{e.message}")
      
      respond_to do |format|
        format.html { redirect_to @customer, alert: "Failed to sync messages: #{e.message}" }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  def refresh
    authorize @customer, :show?
    
    if @customer.whatsapp_chat_id.blank?
      respond_to do |format|
        format.html { redirect_to @customer, alert: 'Customer does not have a WhatsApp chat ID.' }
        format.json { render json: { success: false, error: 'Customer does not have a WhatsApp chat ID.' }, status: :unprocessable_entity }
      end
      return
    end
    
    begin
      # Delete all existing messages for this customer
      deleted_count = @customer.messages.destroy_all.count
      Rails.logger.info("Deleted #{deleted_count} messages for customer #{@customer.id}")
      
      # Fetch new messages from WhatsApp API
      whatsapp_service = WhatsappMessageService.new
      result = whatsapp_service.fetch_and_store_messages(@customer.whatsapp_chat_id, @customer)
      
      if result[:success]
        respond_to do |format|
          format.html { redirect_to @customer, notice: "Refreshed chats: deleted #{deleted_count} old messages, fetched #{result[:messages_count]} new messages." }
          format.json { render json: { success: true, deleted_count: deleted_count, fetched_count: result[:messages_count] } }
        end
      else
        respond_to do |format|
          format.html { redirect_to @customer, alert: "Deleted #{deleted_count} messages but failed to fetch new ones: #{result[:error]}" }
          format.json { render json: { success: false, deleted_count: deleted_count, error: result[:error] }, status: :unprocessable_entity }
        end
      end
    rescue => e
      Rails.logger.error("Failed to refresh WhatsApp messages for customer #{@customer.id}: #{e.message}")
      
      respond_to do |format|
        format.html { redirect_to @customer, alert: "Failed to refresh messages: #{e.message}" }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  def webhook
    # Log the webhook request for debugging
    Rails.logger.info "Webhook accessed: #{request.method} #{request.url}"
    Rails.logger.info "Headers: #{request.headers.to_h.select { |k,v| k.start_with?('HTTP_') }}"
    Rails.logger.info "Params: #{params.inspect}"


    if params[:event] == "message_received"
      customer = Customer.find_by(phone: "+#{params[:contact][:number]}")


      if customer.blank?
        customer = Customer.create(name: 'Whatsapp Lead update name manually',
                                   whatsapp_chat_id: "#{params[:contact][:number]}.c.us",
                                   phone: "+#{params[:contact][:number]}", lead_source: 'WA')
      end


      if params[:message][:body].present?
        message = Message.new(customer: customer,
                              content:  params[:message][:body],
                              message_id: params[:message][:id],
                              direction: 'inbound',
                              message_type: 'chat',
                              status: 'pending')

        if message.save
          if customer.user.present?
            UserMailer.whatsapp_message_notification(customer.user.email, customer, params[:message][:body]).deliver_now
          else
            UserMailer.whatsapp_message_notification('sarmad.mansoor@tecaudex.com', customer, params[:message][:body]).deliver_now
          end
        end
      else
        return
      end

    elsif params[:typeWebhook] == "incomingCall"

      customer = Customer.find_by(whatsapp_chat_id: params[:from])
      if customer.present?
        if customer.user.present?
          UserMailer.whatsapp_call_notification(customer.user.email, customer).deliver_now
        else
          UserMailer.whatsapp_call_notification('sarmad.mansoor@tecaudex.com', customer).deliver_now
        end
      else
        UserMailer.whatsapp_call_notification('sarmad.mansoor@tecaudex.com', customer).deliver_now
      end
    end
    head :ok
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def valid_file?(file)
    return false unless file.present?
    
    # Check file type first
    allowed_types = [
      # Images
      'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp',
      # Videos
      'video/mp4', 'video/3gp', 'video/mov', 'video/avi', 'video/webm',
      # Audio
      'audio/mp3', 'audio/wav', 'audio/ogg', 'audio/m4a', 'audio/mpeg', 'audio/flac',
      # Documents
      'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'application/zip', 'text/plain', 'text/csv', 'application/json', 'application/xml'
    ]
    
    # Check content type
    return false unless allowed_types.include?(file.content_type)
    
    # Check file extension
    allowed_extensions = %w[jpg jpeg png gif webp mp4 3gp mov avi webm mp3 wav ogg m4a flac pdf doc docx xls xlsx pptx zip txt csv json xml]
    extension = File.extname(file.original_filename).delete('.').downcase
    return false unless allowed_extensions.include?(extension)
    
    # Check file size based on type (realistic WhatsApp API limits)
    file_size_mb = file.size.to_f / 1.megabyte
    content_type = file.content_type
    
    max_size = case content_type
               when /^image\//
                 5 # 5MB for images
               when /^video\//
                 16 # 16MB for videos
               when /^audio\//
                 16 # 16MB for audio
               when /pdf/, /document/, /spreadsheet/, /presentation/, /text/, /json/, /xml/
                 5 # 5MB for documents
               else
                 5 # 5MB default
               end
    
    if file_size_mb > max_size
      Rails.logger.warn("File size validation failed: #{file_size_mb.round(1)}MB > #{max_size}MB limit for #{content_type}")
      return false
    end
    
    true
  end

  def validate_file_with_details(file)
    return { valid: false, error: 'No file provided' } unless file.present?
    
    # Check file type first
    allowed_types = [
      # Images
      'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp',
      # Videos
      'video/mp4', 'video/3gp', 'video/mov', 'video/avi', 'video/webm',
      # Audio
      'audio/mp3', 'audio/wav', 'audio/ogg', 'audio/m4a', 'audio/mpeg', 'audio/flac',
      # Documents
      'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'application/zip', 'text/plain', 'text/csv', 'application/json', 'application/xml'
    ]
    
    # Check content type
    unless allowed_types.include?(file.content_type)
      return { valid: false, error: "File type '#{file.content_type}' is not supported" }
    end
    
    # Check file extension
    allowed_extensions = %w[jpg jpeg png gif webp mp4 3gp mov avi webm mp3 wav ogg m4a flac pdf doc docx xls xlsx pptx zip txt csv json xml]
    extension = File.extname(file.original_filename).delete('.').downcase
    unless allowed_extensions.include?(extension)
      return { valid: false, error: "File extension '.#{extension}' is not supported" }
    end
    
    # Check file size based on type
    file_size_mb = file.size.to_f / 1.megabyte
    content_type = file.content_type
    
    max_size, type_name = case content_type
                          when /^image\//
                            [5, 'image']
                          when /^video\//
                            [16, 'video']
                          when /^audio\//
                            [16, 'audio']
                          when /pdf/, /document/, /spreadsheet/, /presentation/, /text/, /json/, /xml/
                            [5, 'document']
                          else
                            [5, 'file']
                          end
    
    if file_size_mb > max_size
      return { 
        valid: false, 
        error: "#{type_name.capitalize} files must be less than #{max_size}MB. Your file is #{file_size_mb.round(1)}MB." 
      }
    end
    
    { valid: true }
  end
end