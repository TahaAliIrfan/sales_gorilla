class MessageService
  attr_reader :user, :customer, :whatsapp_api
  
  def initialize(user: nil, customer: nil)
    @user = user
    @customer = customer
    @whatsapp_api = Whatsapp::ApiService.new
  end
  
  # Send a message from a user to a customer
  def send_message(content, message_type: 'text', metadata: {})
    return { success: false, error: 'Either user or customer must be specified' } unless user.present? || customer.present?
    
    if customer.present? && customer.phone.present?
      # Get WhatsApp chat ID for the customer's phone
      chat_id = @whatsapp_api.get_chat_id_from_phone(customer.phone)
      
      if chat_id.present?
        # Send message via WhatsApp
        api_response = if message_type == 'text'
          @whatsapp_api.send_text_message(chat_id, content)
        elsif ['image', 'video', 'audio', 'document'].include?(message_type)
          @whatsapp_api.send_media_message(chat_id, metadata[:url], metadata[:caption], message_type)
        else
          { success: false, error: "Unsupported message type: #{message_type}" }
        end
        
        if api_response[:success]
          # Create message record
          message = Message.create!(
            content: content,
            message_type: message_type,
            status: 'sent',
            message_id: api_response[:data][:id],
            direction: 'outbound',
            user: user,
            customer: customer,
            whatsapp_chat_id: chat_id,
            metadata: metadata
          )
          
          return { success: true, message: message }
        else
          return { success: false, error: api_response[:error] }
        end
      else
        return { success: false, error: 'Failed to get WhatsApp chat ID for the phone number' }
      end
    else
      return { success: false, error: 'Customer phone number is not available' }
    end
  end
  
  # Fetch messages between user and customer
  def fetch_messages(page: 1, limit: 50)
    return { success: false, error: 'Either user or customer must be specified' } unless user.present? || customer.present?
    
    messages = Message.where(customer: customer)
    messages = messages.where(user: user) if user.present?
    messages = messages.order(created_at: :desc).page(page).per(limit)
    
    { success: true, messages: messages }
  end
  
  # Fetch messages from WhatsApp and store in database
  def sync_messages_from_whatsapp
    return { success: false, error: 'Customer must be specified with a valid phone number' } unless customer.present? && customer.phone.present?
    
    # Get WhatsApp chat ID for the customer's phone
    chat_id = @whatsapp_api.get_chat_id_from_phone(customer.phone)
    
    if chat_id.present?
      # Fetch messages from WhatsApp
      api_response = @whatsapp_api.get_chat_messages(chat_id)
      
      if api_response[:success] && api_response[:data][:messages].present?
        new_messages_count = 0
        
        api_response[:data][:messages].each do |msg|
          # Skip if message already exists
          next if Message.exists?(message_id: msg[:id])
          
          # Determine direction based on WhatsApp from/to
          is_from_me = msg[:fromMe]
          direction = is_from_me ? 'outbound' : 'inbound'
          
          # Create message record
          Message.create!(
            content: msg[:body] || '',
            message_type: determine_message_type(msg),
            status: determine_message_status(msg),
            message_id: msg[:id],
            direction: direction,
            user: is_from_me ? user : nil,
            customer: customer,
            whatsapp_chat_id: chat_id,
            metadata: extract_metadata(msg),
            created_at: Time.at(msg[:timestamp])
          )
          
          new_messages_count += 1
        end
        
        return { success: true, new_messages_count: new_messages_count }
      else
        return { success: false, error: api_response[:error] || 'No messages found' }
      end
    else
      return { success: false, error: 'Failed to get WhatsApp chat ID for the phone number' }
    end
  end
  
  # Mark messages as read
  def mark_messages_as_read(chat_id)
    api_response = @whatsapp_api.mark_messages_as_seen(chat_id)
    
    if api_response[:success]
      # Update local message statuses if needed
      Message.where(whatsapp_chat_id: chat_id, direction: 'inbound').update_all(status: 'read')
      return { success: true }
    else
      return { success: false, error: api_response[:error] }
    end
  end
  
  private
  
  # Determine message type based on WhatsApp message
  def determine_message_type(whatsapp_message)
    if whatsapp_message[:type] == 'chat'
      'text'
    else
      whatsapp_message[:type]
    end
  end
  
  # Determine message status based on WhatsApp message
  def determine_message_status(whatsapp_message)
    status = whatsapp_message[:status]
    
    case status
    when 0
      'pending'
    when 1
      'sent'
    when 2
      'delivered'
    when 3
      'read'
    else
      'pending'
    end
  end
  
  # Extract metadata from WhatsApp message
  def extract_metadata(whatsapp_message)
    metadata = {}
    
    case whatsapp_message[:type]
    when 'image', 'video', 'audio', 'document'
      metadata[:mimetype] = whatsapp_message[:mimetype]
      metadata[:filename] = whatsapp_message[:filename]
      metadata[:caption] = whatsapp_message[:caption]
    when 'location'
      metadata[:latitude] = whatsapp_message[:lat]
      metadata[:longitude] = whatsapp_message[:lng]
    end
    
    metadata
  end
end 