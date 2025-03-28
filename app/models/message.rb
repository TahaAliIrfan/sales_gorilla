class Message < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :customer, optional: true
  
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
    'contact' => 'contact'
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
  validates :status, inclusion: { in: MESSAGE_STATUSES.values }
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
  
  private
  
  # Ensure at least one of user or customer is present
  def at_least_one_participant
    if user.nil? && customer.nil?
      errors.add(:base, "Message must be associated with at least one participant (user or customer)")
    end
  end
  
  # Set default status based on direction
  def set_default_status
    self.status ||= inbound? ? 'delivered' : 'pending'
  end
end
