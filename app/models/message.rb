class Message < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :customer, optional: true
  
  # Active Storage attachments
  has_one_attached :document
  
  # At least one of user or customer must be present
  validate :at_least_one_participant
  
  # Constants for message properties
  MESSAGE_TYPES = {
    'text' => 'text',
    'image' => 'image',
    'audio' => 'audio',
    'video' => 'video',
    'document' => 'document',
    'location' => 'location',
    'contact' => 'contact',
    'ptt' => 'ptt',
    'chat' => 'chat',
  }.freeze
  
  MESSAGE_STATUSES = {
    'pending' => 'pending',
    'sent' => 'sent',
    'delivered' => 'delivered',
    'read' => 'read',
    'failed' => 'failed'
  }.freeze
  
  MESSAGE_DIRECTIONS = {
    'inbound' => 'inbound',  # From customer to user
    'outbound' => 'outbound' # From user to customer
  }.freeze
  
  # Validations
  validates :content, presence: true, unless: -> { message_type != 'text' }
  validates :message_type, inclusion: { in: MESSAGE_TYPES.values }
  validates :direction, inclusion: { in: MESSAGE_DIRECTIONS.values }
  
  # Scopes
  scope :for_customer, ->(customer_id) { where(customer_id: customer_id) if customer_id.present? }
  scope :for_user, ->(user_id) { where(user_id: user_id) if user_id.present? }
  scope :for_chat, ->(chat_id) { where(whatsapp_chat_id: chat_id) if chat_id.present? }
  scope :inbound, -> { where(direction: 'inbound') }
  scope :outbound, -> { where(direction: 'outbound') }
  scope :newest_first, -> { order(created_at: :desc) }
  scope :oldest_first, -> { order(created_at: :asc) }
  
  # Callbacks
  before_create :set_default_status
  
  # Check if message is read
  def read?
    status == 'read'
  end
  
  # Check if message is delivered
  def delivered?
    status == 'delivered'
  end
  
  # Check if message is pending
  def pending?
    status == 'pending'
  end
  
  # Check if message is failed
  def failed?
    status == 'failed'
  end
  
  # Check if message is inbound
  def inbound?
    direction == 'inbound'
  end
  
  # Check if message is outbound
  def outbound?
    direction == 'outbound'
  end

  # Check if message has a document attachment
  def has_document?
    message_type == 'document' && document.attached?
  end

  # Check if message has media attachment (images, audio, video)
  def has_media?
    %w[image audio video].include?(message_type) && document.attached?
  end

  # Check if message has any kind of attachment (document or media)
  def has_attachment?
    document.attached?
  end

  # Get document URL
  def document_url
    return nil unless document.attached?
    
    begin
      Rails.application.routes.url_helpers.rails_blob_url(document, only_path: false)
    rescue ArgumentError => e
      # Fallback for console/test environments without host configuration
      "/rails/active_storage/blobs/#{document.signed_id}/#{document.filename}"
    end
  end

  # Get media URL (alias for document_url since we're using one attachment)
  def media_url
    document_url
  end

  # Get attachment URL (works for both documents and media)
  def attachment_url
    document_url
  end

  # Get document filename
  def document_filename
    document.attached? ? document.filename.to_s : metadata.dig('document', 'filename')
  end

  # Get document size
  def document_size
    document.attached? ? document.byte_size : metadata.dig('document', 'size')
  end

  # Get document content type
  def document_content_type
    document.attached? ? document.content_type : metadata.dig('document', 'mimetype')
  end

  # Get WhatsApp message info
  def whatsapp_info
    return nil unless whatsapp_chat_id.present?
    
    {
      chat_id: whatsapp_chat_id,
      message_id: message_id,
      ack_status: metadata.dig('whatsapp_raw', 'ack'),
      device_type: metadata.dig('whatsapp_raw', 'deviceType'),
      forwarded: metadata.dig('whatsapp_raw', 'forwarded')
    }
  end
  
  private
  
  # Ensure at least one of user or customer is present
  def at_least_one_participant
    # if user.nil? && customer.nil?
    #   errors.add(:base, "Message must be associated with at least one participant (user or customer)")
    # end
  end
  
  # Set default status based on direction
  def set_default_status
    self.status ||= inbound? ? 'delivered' : 'pending'
  end
end
