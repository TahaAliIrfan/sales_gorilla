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
    conversations.each do |conversation_data|
      next unless conversation_data.is_a?(Hash)
      
      conversation_id = conversation_data['conversation_id'] || conversation_data['id']
      next unless conversation_id
      
      # Skip if already exists
      next if exists?(conversation_id: conversation_id)
      
      # Try to match customer by phone number
      customer = find_customer_by_phone(conversation_data)
      
      ai_conversation = create_from_api_data(conversation_data, customer)
      synced_conversations << ai_conversation if ai_conversation
    end
    
    synced_conversations
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
            conversation_data['from']
    
    # Clean phone number (remove +1, spaces, dashes, etc.)
    phone&.gsub(/[\+\-\s\(\)]/, '')
  end

  def self.create_from_api_data(conversation_data, customer = nil)
    conversation_id = conversation_data['conversation_id'] || conversation_data['id']
    
    create!(
      conversation_id: conversation_id,
      status: conversation_data['status'] || 'unknown',
      duration_seconds: conversation_data['duration_seconds']&.to_i,
      agent_id: conversation_data.dig('agent', 'agent_id') || conversation_data['agent_id'],
      call_from: conversation_data.dig('call', 'from') || conversation_data['from'],
      call_to: conversation_data.dig('call', 'to') || conversation_data['to'],
      conversation_date: parse_conversation_date(conversation_data['created_at']),
      transcript: conversation_data['transcript'],
      raw_data: conversation_data,
      customer: customer,
      user: nil # We'll set this later if we can determine it
    )
  rescue => e
    Rails.logger.error("Failed to create AiConversation from API data: #{e.message}")
    Rails.logger.error("API data: #{conversation_data}")
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
