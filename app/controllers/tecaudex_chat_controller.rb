class TecaudexChatController < ApplicationController
  before_action :require_login
  before_action :set_whatsapp_service
  
  # Skip CSRF token verification for AJAX requests
  skip_before_action :verify_authenticity_token, only: [:load_chat, :send_message, :send_media, :refresh_messages, :refresh_chat_list]

  def index
    @chat_result = @whatsapp_service.get_chat_lists
    
    if @chat_result[:success]
      @chats = @chat_result[:chats] || []
    else
      @chats = []
      flash.now[:error] = @chat_result[:error] || "Failed to load chats"
    end
  end

  def show
    @chat_id = params[:id]
    @customer = find_customer_by_chat_id(@chat_id)
    
    # Fetch and store messages for this chat
    messages_result = @whatsapp_service.fetch_and_store_messages(@chat_id, @customer)
    
    if messages_result[:success]
      @messages = @customer&.messages&.where(whatsapp_chat_id: @chat_id)&.order(:created_at) || []
    else
      @messages = []
      flash.now[:error] = messages_result[:error] || "Failed to load messages"
    end

    # Get chat info from the chat list for display
    chat_list_result = @whatsapp_service.get_chat_lists
    if chat_list_result[:success]
      @chat_info = chat_list_result[:chats]&.find { |chat| chat[:id] == @chat_id }
    end
    @chat_info ||= { name: @chat_id, id: @chat_id }
  end

  def send_message
    @chat_id = params[:id]
    message_content = params[:message_content]
    @customer = find_customer_by_chat_id(@chat_id)

    if message_content.blank?
      render json: { success: false, error: "Message content cannot be blank" }
      return
    end

    result = @whatsapp_service.send_message(@chat_id, message_content, @customer)
    
    if result[:success]
      render json: { 
        success: true, 
        message: "Message sent successfully"
      }
    else
      render json: { 
        success: false, 
        error: result[:error] || "Failed to send message"
      }
    end
  end

  def send_media
    @chat_id = params[:id]
    @customer = find_customer_by_chat_id(@chat_id)
    
    uploaded_file = params[:file]
    caption = params[:caption]

    if uploaded_file.blank?
      render json: { success: false, error: "No file provided" }
      return
    end

    begin
      # Read raw file data
      file_data = uploaded_file.read
      filename = uploaded_file.original_filename

      result = @whatsapp_service.send_media_message(@chat_id, file_data, filename, caption, @customer)
      
      if result[:success]
        render json: { 
          success: true, 
          message: "Media message sent successfully"
        }
      else
        render json: { 
          success: false, 
          error: result[:error] || "Failed to send media message"
        }
      end
    rescue StandardError => e
      Rails.logger.error("TecaudexChat send_media error: #{e.message}")
      render json: { 
        success: false, 
        error: "Failed to process media file: #{e.message}"
      }
    end
  end

  def load_chat
    @chat_id = params[:id]
    @customer = find_customer_by_chat_id(@chat_id)

    unless @customer.present?
      @customer = Customer.create(name: @chat_id, whatsapp_chat_id: @chat_id)
    end
    # Fetch and store messages for this chat
    messages_result = @whatsapp_service.fetch_and_store_messages(@chat_id, @customer)
    
    if messages_result[:success]
      @messages = Message.where(customer: @customer)|| []
      
      # Get chat info from the chat list for display
      chat_list_result = @whatsapp_service.get_chat_lists
      if chat_list_result[:success]
        @chat_info = chat_list_result[:chats]&.find { |chat| chat[:id] == @chat_id }
      end
      @chat_info ||= { name: @chat_id, id: @chat_id }

      # Extract phone number and get display name
      phone_number = @chat_id.gsub(/@c\.us$/, '')
      display_name = @customer&.name || @chat_info[:name] || phone_number

      # Format messages as JSON
      formatted_messages = @messages.map do |message|
        {
          id: message.id,
          content: message.content,
          message_type: message.message_type,
          direction: message.direction,
          created_at: message.created_at.strftime("%H:%M"),
          status: message.status,
          customer_name: message.customer&.name&.first&.upcase || '?',
          has_attachment: message.document.attached?,
          attachment_url: message.document.attached? ? rails_blob_path(message.document, disposition: "attachment") : nil,
          attachment_filename: message.document.attached? ? message.document.filename.to_s : nil,
          is_image: message.message_type == 'image' && message.document.attached?,
          image_url: (message.message_type == 'image' && message.document.attached?) ? rails_blob_path(message.document) : nil
        }
      end

      render json: {
        success: true,
        chat_id: @chat_id,
        contact_name: display_name,
        contact_info: @customer ? "Customer: #{@customer.company.present? ? @customer.company : @customer.phone}" : "Phone: #{phone_number}",
        contact_avatar: display_name.first.upcase,
        customer_id: @customer&.id,
        messages: formatted_messages
      }
    else
      render json: { 
        success: false, 
        error: messages_result[:error] || "Failed to load chat"
      }
    end
  end

  def refresh_messages
    @chat_id = params[:id]
    @customer = find_customer_by_chat_id(@chat_id)
    
    # Fetch and store latest messages
    messages_result = @whatsapp_service.fetch_and_store_messages(@chat_id, @customer)
    
    if messages_result[:success]
      @messages = @customer&.messages&.where(whatsapp_chat_id: @chat_id)&.order(:created_at) || []
      
      # Format messages as JSON
      formatted_messages = @messages.map do |message|
        {
          id: message.id,
          content: message.content,
          message_type: message.message_type,
          direction: message.direction,
          created_at: message.created_at.strftime("%H:%M"),
          status: message.status,
          customer_name: message.customer&.name&.first&.upcase || '?',
          has_attachment: message.document.attached?,
          attachment_url: message.document.attached? ? rails_blob_path(message.document, disposition: "attachment") : nil,
          attachment_filename: message.document.attached? ? message.document.filename.to_s : nil,
          is_image: message.message_type == 'image' && message.document.attached?,
          image_url: (message.message_type == 'image' && message.document.attached?) ? rails_blob_path(message.document) : nil
        }
      end
      
      render json: {
        success: true,
        messages: formatted_messages
      }
    else
      render json: { 
        success: false, 
        error: messages_result[:error] || "Failed to refresh messages"
      }
    end
  end

  def refresh_chat_list
    @chat_result = @whatsapp_service.get_chat_lists
    
    if @chat_result[:success]
      @chats = @chat_result[:chats] || []
      
      # Format chats as JSON
      formatted_chats = @chats.map do |chat|
        phone_number = chat[:id].gsub(/@c\.us$/, '')
        customer = Customer.find_by(phone: phone_number) ||
                  Customer.find_by(phone: "+#{phone_number}") ||
                  Customer.where("phone LIKE ?", "%#{phone_number.last(10)}").first
        display_name = customer&.name || chat[:name] || phone_number
        
        {
          id: chat[:id],
          name: display_name,
          phone_number: phone_number,
          customer_info: customer ? "Customer: #{customer.company.present? ? customer.company : customer.phone}" : "Phone: #{phone_number}",
          avatar: display_name.first.upcase,
          unread_count: chat[:unreadCount] || 0,
          timestamp: chat[:timestamp],
          last_message: chat[:lastMessage],
          is_customer: customer.present?
        }
      end
      
      render json: {
        success: true,
        chats: formatted_chats
      }
    else
      render json: { 
        success: false, 
        error: @chat_result[:error] || "Failed to refresh chat list"
      }
    end
  end

  private

  def set_whatsapp_service
    @whatsapp_service = WhatsappMessageService.new
  end

  def find_customer_by_chat_id(chat_id)
    # Extract phone number from chat ID (format: phone@c.us)
    phone_number = chat_id.gsub(/@c\.us$/, '')
    
    # Try to find customer by phone number with various formats
    customer = Customer.find_by(phone: phone_number) ||
               Customer.find_by(phone: "+#{phone_number}") ||
               Customer.where("phone LIKE ?", "%#{phone_number.last(10)}").first if phone_number.length >= 10
    
    customer
  end
end