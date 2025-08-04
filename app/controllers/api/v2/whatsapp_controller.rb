require 'securerandom'

class Api::V2::WhatsappController < Api::V2::BaseController
  def index
    begin
      customers = accessible_customers
      
      # Get all WhatsApp messages for accessible customers
      messages = WhatsappMessage.joins(:customer)
                               .where(customer: customers)
                               .includes(:customer)
                               .order(created_at: :desc)
                               .limit(params[:limit]&.to_i || 100)
      
      formatted_messages = messages.map do |message|
        {
          id: message.id,
          customer_id: message.customer_id,
          customer_name: message.customer.name,
          customer_phone: message.customer.phone,
          message_id: message.message_id,
          content: message.body,
          direction: message.direction,
          is_from_me: message.direction == 'outbound',
          timestamp: message.timestamp,
          created_at: message.created_at
        }
      end
      
      render_success(formatted_messages, "WhatsApp messages retrieved successfully")
    rescue => e
      Rails.logger.error "WhatsApp index error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render_error("Failed to retrieve WhatsApp messages: #{e.message}", nil, :internal_server_error)
    end
  end
  
  def show_customer_messages
    customer = accessible_customers.find(params[:customer_id])
    
    # Get WhatsApp messages for specific customer
    messages = customer.whatsapp_messages
                      .order(created_at: :desc)
                      .limit(params[:limit]&.to_i || 100)
    
    formatted_messages = messages.map do |message|
      {
        id: message.id,
        customer_id: message.customer_id,
        message_id: message.message_id,
        content: message.body,
        direction: message.direction,
        is_from_me: message.direction == 'outbound',
        timestamp: message.timestamp,
        created_at: message.created_at
      }
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
    customer = accessible_customers.find(params[:customer_id])
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
    customer = accessible_customers.find(params[:customer_id])
    image_url = params[:image_url]&.strip
    caption = params[:caption]&.strip
    
    if image_url.blank?
      return render_error("Image URL cannot be empty", nil, :unprocessable_entity)
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
    
    # Send image message via WhatsApp API
    result = whatsapp_service.send_media_message(chat_id, image_url, caption, 'image')
    
    if result[:success]
      # Create WhatsApp message record
      message = customer.whatsapp_messages.create!(
        message_id: SecureRandom.uuid,
        body: caption || "[Image sent]",
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
      }, "Image message sent successfully")
    else
      render_error("Failed to send WhatsApp image: #{result[:error]}", nil, :service_unavailable)
    end
  end
  
  def sync_messages
    customer = accessible_customers.find(params[:customer_id])
    
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
  
  def accessible_customers
    return Customer.none unless current_user
    
    begin
      role_key = current_user.highest_role&.key
      case role_key
      when 'admin'
        Customer.all
      when 'manager'
        # Manager can see their own customers and their associates' customers
        associate_user_ids = current_user.associates.pluck(:id)
        all_user_ids = [current_user.id] + associate_user_ids
        Customer.where(user_id: all_user_ids)
      else
        # Associate/regular users can only see their own customers
        current_user.customers
      end
    rescue => e
      Rails.logger.error "Error determining accessible customers: #{e.message}"
      # Fallback to user's own customers only
      current_user.customers
    end
  end
  
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
end