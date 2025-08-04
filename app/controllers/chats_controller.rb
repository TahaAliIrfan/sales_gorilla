class ChatsController < ApplicationController
  before_action :require_login
  before_action :check_whatsapp_credentials
  before_action :set_chat, only: [:show, :send_message, :mark_as_seen, :send_typing, :stop_typing, :send_media]

  def index
    @whatsapp_service = Whatsapp::ApiService.new
    @instance_id = @whatsapp_service.instance_id
    
    # Check WhatsApp client status
    client_status = @whatsapp_service.get_client_status
    @client_connected = client_status[:success]
    
    response = @whatsapp_service.get_chats

    if response[:success]
      # The API returns the chats data differently than expected
      # It's directly in the data field, not in a chats sub-field
      @chats = response[:data][:data] || []
      
      # Log the first chat structure for debugging
      if @chats.any?
        Rails.logger.debug "First chat structure: #{@chats.first.inspect}"
      end
      
      if @chats.empty?
        flash.now[:notice] = "No chats found. Make sure your WhatsApp instance is properly connected."
      end
    else
      @chats = []
      flash.now[:error] = "Could not fetch chats: #{response[:error]}"
      @api_error = response[:error]
    end

    # Handle JSON requests
    respond_to do |format|
      format.html # renders the normal view
      format.json { 
        if response[:success]
          render json: { 
            success: true, 
            chats: @chats,
            client_connected: @client_connected
          }
        else
          render json: { 
            success: false, 
            error: @api_error || "Failed to fetch chats",
            chats: []
          }
        end
      }
    end
  end

  def show
    @whatsapp_service = Whatsapp::ApiService.new
    
    # Send typing indicator when loading chat
    @whatsapp_service.send_typing(@chat_id)
    
    response = @whatsapp_service.get_chat_messages(@chat_id)
    
    if response[:success]
      @messages = response[:data][:messages] || []
      
      # Log the first message structure for debugging
      if @messages.any?
        Rails.logger.debug "First message structure: #{@messages.first.inspect}"
      end
      
      # Mark messages as seen
      @whatsapp_service.mark_messages_as_seen(@chat_id)
    else
      @messages = []
      flash.now[:error] = "Could not fetch messages: #{response[:error]}"
    end

    # Stop typing indicator after loading messages
    @whatsapp_service.stop_typing(@chat_id)
    
    # Get chat details for the header
    chat_response = @whatsapp_service.get_chat_by_id(@chat_id)
    if chat_response[:success]
      @chat_details = chat_response[:data][:chat]
      Rails.logger.debug "Chat details: #{@chat_details.inspect}"
    end
    
    # Get all chats for the sidebar
    all_chats_response = @whatsapp_service.get_chats
    if all_chats_response[:success]
      @chats = all_chats_response[:data][:data] || []
    else
      @chats = []
    end

    # Handle JSON requests
    respond_to do |format|
      format.html # renders the normal view
      format.json { 
        if response[:success]
          render json: { 
            success: true, 
            messages: @messages,
            chat_details: @chat_details
          }
        else
          render json: { 
            success: false, 
            error: response[:error] || "Failed to fetch messages",
            messages: []
          }
        end
      }
    end
  end

  def send_message
    @whatsapp_service = Whatsapp::ApiService.new
    
    message_text = params[:message]
    return head :bad_request if message_text.blank?
    
    # Send typing indicator
    @whatsapp_service.send_typing(@chat_id)
    
    # Send the message
    response = @whatsapp_service.send_text_message(@chat_id, message_text)
    
    # Stop typing indicator
    @whatsapp_service.stop_typing(@chat_id)
    
    if response[:success]
      # Broadcast the message to connected clients
      if response[:data][:message].present?
        ActionCable.server.broadcast(
          "chat_#{@chat_id}",
          { 
            message: response[:data][:message], 
            fromMe: true
          }
        )
      end
      
      render json: { success: true, message: response[:data] }
    else
      render json: { success: false, error: response[:error] }, status: :unprocessable_entity
    end
  end
  
  def mark_as_seen
    @whatsapp_service = Whatsapp::ApiService.new
    response = @whatsapp_service.mark_messages_as_seen(@chat_id)
    
    if response[:success]
      render json: { success: true }
    else
      render json: { success: false, error: response[:error] }, status: :unprocessable_entity
    end
  end
  
  def send_typing
    @whatsapp_service = Whatsapp::ApiService.new
    response = @whatsapp_service.send_typing(@chat_id)
    
    if response[:success]
      # Broadcast typing indicator to connected clients
      ActionCable.server.broadcast(
        "chat_#{@chat_id}",
        { typing: 'start' }
      )
      
      render json: { success: true }
    else
      render json: { success: false, error: response[:error] }, status: :unprocessable_entity
    end
  end
  
  def stop_typing
    @whatsapp_service = Whatsapp::ApiService.new
    response = @whatsapp_service.stop_typing(@chat_id)
    
    if response[:success]
      # Broadcast typing stopped to connected clients
      ActionCable.server.broadcast(
        "chat_#{@chat_id}",
        { typing: 'stop' }
      )
      
      render json: { success: true }
    else
      render json: { success: false, error: response[:error] }, status: :unprocessable_entity
    end
  end

  def send_media
    @whatsapp_service = Whatsapp::ApiService.new
    
    # Check if media is present
    if params[:media_url].blank?
      return render json: { success: false, error: "Media URL is required" }, status: :bad_request
    end
    
    # Determine media type from URL or params
    media_type = params[:media_type] || 'image'
    unless ['image', 'video', 'audio', 'document'].include?(media_type)
      media_type = 'image' # Default to image if invalid type
    end
    
    # Send typing indicator
    @whatsapp_service.send_typing(@chat_id)
    
    # Send the media message
    response = @whatsapp_service.send_media_message(
      @chat_id, 
      params[:media_url], 
      params[:caption], 
      media_type
    )
    
    # Stop typing indicator
    @whatsapp_service.stop_typing(@chat_id)
    
    if response[:success]
      # Broadcast the message to connected clients
      if response[:data][:message].present?
        ActionCable.server.broadcast(
          "chat_#{@chat_id}",
          { 
            message: response[:data][:message], 
            fromMe: true
          }
        )
      end
      
      render json: { success: true, message: response[:data] }
    else
      render json: { success: false, error: response[:error] }, status: :unprocessable_entity
    end
  end

  def get_chat_id
    @whatsapp_service = Whatsapp::ApiService.new
    phone_number = params[:phone]
    
    if phone_number.blank?
      return render json: { success: false, error: "Phone number is required" }, status: :bad_request
    end
    
    # Check if the number is registered on WhatsApp
    is_registered = @whatsapp_service.is_registered_on_whatsapp(phone_number)
    
    if is_registered
      chat_id = @whatsapp_service.get_chat_id_from_phone(phone_number)
      if chat_id.present?
        render json: { success: true, chat_id: chat_id }
      else
        render json: { success: false, error: "Could not get chat ID for this number" }, status: :unprocessable_entity
      end
    else
      render json: { success: false, error: "This number is not registered on WhatsApp" }, status: :unprocessable_entity
    end
  end

  private

  def set_chat
    @chat_id = CGI.unescape(params[:id])
  end
  
  def check_whatsapp_credentials
    service = Whatsapp::ApiService.new
    unless service.credentials_configured?
      flash[:error] = "WhatsApp API credentials are not configured. Please check your Rails credentials for WAAPI_INSTANCE_ID and WAAPI_AUTH_TOKEN."
      redirect_to root_path
    end
  end
end 