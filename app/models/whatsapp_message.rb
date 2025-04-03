class WhatsappMessage < ApplicationRecord
  belongs_to :customer
  
  validates :message_id, presence: true, uniqueness: true
  validates :direction, presence: true, inclusion: { in: ['inbound', 'outbound'] }
  
  # Scopes
  scope :ordered, -> { order(timestamp: :asc) }
  scope :recent, -> { order(timestamp: :desc) }
  scope :inbound, -> { where(direction: 'inbound') }
  scope :outbound, -> { where(direction: 'outbound') }
  
  # Class methods
  
  # Import a message from the WhatsApp API
  # Returns the created/updated message object
  def self.import_from_api(customer, message_data)
    return nil unless customer.present? && message_data.present?
    
    data = message_data.dig(:message, :_data)
    return nil unless data.present?
    
    # Skip system messages or messages without content
    return nil if data[:type] == "e2e_notification" || !message_data.dig(:message, :body)
    
    # Get message ID
    message_id = data.dig(:id, :_serialized) || SecureRandom.uuid
    
    # Determine direction
    direction = data[:fromMe] ? 'outbound' : 'inbound'
    
    Rails.logger.info("Processing WhatsApp message - ID: #{message_id}, Direction: #{direction}")
    
    # Create or update the message
    message = WhatsappMessage.find_by(message_id: message_id) 
    
    if message.nil?
      Rails.logger.info("Creating new WhatsApp message in database")
      message = WhatsappMessage.new(
        customer: customer,
        message_id: message_id,
        remote_id: data.dig(:id, :id),
        body: message_data.dig(:message, :body),
        timestamp: data[:t] ? Time.at(data[:t]) : Time.current,
        direction: direction,
        status: data[:status] || 'received',
        metadata: data
      )
      
      begin
        message.save!
        Rails.logger.info("Successfully saved WhatsApp message ID: #{message_id}")
      rescue => e
        Rails.logger.error("Failed to save WhatsApp message: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end
    else
      Rails.logger.info("WhatsApp message ID: #{message_id} already exists in database")
    end
    
    message
  end
  
  # Import multiple messages for a customer
  def self.import_messages(customer, messages)
    return [] unless customer.present? && messages.present?
    
    imported = []
    messages.each do |message_data|
      message = import_from_api(customer, message_data)
      imported << message if message.present?
    end
    
    imported
  end
end
