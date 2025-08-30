class AiConversation < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :customer, optional: true

  validates :conversation_id, presence: true, uniqueness: true
  validates :status, presence: true
  
  scope :recent, -> { order(conversation_date: :desc, created_at: :desc) }
  scope :completed, -> { where(status: 'completed') }
  scope :active, -> { where(status: 'active') }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_customer, ->(customer) { where(customer: customer) }

  def self.sync_from_api
    service = ElevenLabsService.new
    conversations = service.fetch_conversations
    
    return [] if conversations.blank?
    
    synced_conversations = []
    updated_conversations = []
    
    conversations.each do |conversation_data|
      next unless conversation_data.is_a?(Hash)
      
      conversation_id = conversation_data['conversation_id'] || conversation_data['id']
      next unless conversation_id
      
      existing_conversation = find_by(conversation_id: conversation_id)
      
      # Fetch detailed conversation data including transcript
      detailed_data = service.fetch_conversation_detail(conversation_id) rescue conversation_data
      
      # Use detailed data if available, otherwise use basic data
      final_data = detailed_data.is_a?(Hash) && detailed_data.any? ? detailed_data : conversation_data
      
      if existing_conversation
        # Update existing conversation with new data
        existing_conversation.update_from_api_data(final_data)
        updated_conversations << existing_conversation
      else
        # Try to match customer by phone number
        customer = find_customer_by_phone(final_data)
        
        ai_conversation = create_from_api_data(final_data, customer)
        synced_conversations << ai_conversation if ai_conversation
      end
    end
    
    Rails.logger.info("Created #{synced_conversations.length} new conversations, updated #{updated_conversations.length} existing conversations")
    synced_conversations + updated_conversations
  end

  def update_from_api_data(conversation_data)
    # Handle different API response formats for duration
    duration = conversation_data['duration_seconds']&.to_i || 
               conversation_data['call_duration_secs']&.to_i

    # Handle different API response formats for date
    date = self.class.parse_conversation_date(conversation_data['created_at']) ||
           self.class.parse_unix_timestamp(conversation_data['start_time_unix_secs'])

    # Handle different status formats  
    status = self.class.map_status(conversation_data['status'])

    # Try to match customer by phone number if not already set
    unless customer
      customer = self.class.find_customer_by_phone(conversation_data)
    end

    # Extract phone numbers from various possible locations
    agent_number = conversation_data.dig('metadata', 'phone_call', 'agent_number') ||
                   conversation_data.dig('call', 'from') ||
                   conversation_data['from'] ||
                   self.call_from
                   
    external_number = conversation_data.dig('metadata', 'phone_call', 'external_number') ||
                      conversation_data.dig('call', 'to') ||
                      conversation_data['to'] ||
                      self.call_to

    update!(
      status: status,
      duration_seconds: duration || self.duration_seconds,
      agent_id: conversation_data.dig('agent', 'agent_id') || conversation_data['agent_id'] || self.agent_id,
      call_from: agent_number,
      call_to: external_number,
      conversation_date: date || self.conversation_date,
      transcript: conversation_data['transcript'] || conversation_data['messages'] || self.transcript,
      raw_data: conversation_data,
      customer: customer || self.customer
    )
  rescue => e
    Rails.logger.error("Failed to update AiConversation #{conversation_id}: #{e.message}")
    false
  end

  def has_transcript?
    transcript.present? && transcript.is_a?(Array) && transcript.any?
  end

  def formatted_duration
    return 'N/A' unless duration_seconds.present?
    
    minutes = duration_seconds / 60
    seconds = duration_seconds % 60
    
    if minutes > 0
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end

  def has_audio?
    return false unless status == 'completed'
    
    # Check if the API indicates audio is available
    raw_data&.dig('has_audio') == true || raw_data&.dig('has_response_audio') == true
  end

  private

  def self.find_customer_by_phone(conversation_data)
    phone_number = extract_phone_number(conversation_data)
    return nil unless phone_number
    
    # Try to find customer by phone number
    Customer.where("phone LIKE ?", "%#{phone_number.last(10)}%").first
  end

  def self.extract_phone_number(conversation_data)
    # Try different possible phone number fields
    phone = conversation_data.dig('call', 'to') ||
            conversation_data.dig('call', 'from') ||
            conversation_data['to'] ||
            conversation_data['from'] ||
            conversation_data.dig('metadata', 'phone_number') ||
            conversation_data.dig('conversation_initiation_client_data', 'phone_number') ||
            conversation_data.dig('metadata', 'phone_call', 'external_number') ||
            conversation_data.dig('metadata', 'phone_call', 'agent_number')
    
    return nil unless phone
    
    # Clean phone number (remove +1, spaces, dashes, etc.)
    cleaned_phone = phone.gsub(/[\+\-\s\(\)]/, '')
    
    # Extract just digits for better matching
    cleaned_phone.gsub(/[^\d]/, '')
  end

  def self.create_from_api_data(conversation_data, customer = nil)
    conversation_id = conversation_data['conversation_id'] || conversation_data['id']
    
    # Handle different API response formats for duration
    duration = conversation_data['duration_seconds']&.to_i || 
               conversation_data['call_duration_secs']&.to_i
    
    # Handle different API response formats for date
    date = parse_conversation_date(conversation_data['created_at']) ||
           parse_unix_timestamp(conversation_data['start_time_unix_secs'])
    
    # Handle different status formats  
    status = map_status(conversation_data['status'])
    
    # Extract phone numbers from various possible locations
    agent_number = conversation_data.dig('metadata', 'phone_call', 'agent_number') ||
                   conversation_data.dig('call', 'from') ||
                   conversation_data['from']
                   
    external_number = conversation_data.dig('metadata', 'phone_call', 'external_number') ||
                      conversation_data.dig('call', 'to') ||
                      conversation_data['to']

    create!(
      conversation_id: conversation_id,
      status: status,
      duration_seconds: duration,
      agent_id: conversation_data.dig('agent', 'agent_id') || conversation_data['agent_id'],
      call_from: agent_number,
      call_to: external_number,
      conversation_date: date,
      transcript: conversation_data['transcript'] || conversation_data['messages'],
      raw_data: conversation_data,
      customer: customer,
      user: nil # We'll set this later if we can determine it
    )
  rescue => e
    Rails.logger.error("Failed to create AiConversation from API data: #{e.message}")
    Rails.logger.error("API data: #{conversation_data}")
    nil
  end

  def self.map_status(api_status)
    case api_status&.downcase
    when 'done', 'completed', 'finished'
      'completed'
    when 'active', 'in_progress', 'ongoing'
      'active'
    else
      api_status || 'unknown'
    end
  end

  def self.parse_unix_timestamp(timestamp)
    return nil unless timestamp
    
    Time.at(timestamp.to_i)
  rescue ArgumentError => e
    Rails.logger.warn("Failed to parse unix timestamp: #{timestamp}")
    nil
  end

  def self.parse_conversation_date(date_string)
    return nil unless date_string
    
    Time.parse(date_string)
  rescue ArgumentError => e
    Rails.logger.warn("Failed to parse conversation date: #{date_string}")
    nil
  end
end
