class Notification < ApplicationRecord
  belongs_to :user
  
  # Constants
  NOTIFICATION_TYPES = {
    'message' => 'message',
    'task' => 'task',
    'deal' => 'deal',
    'system' => 'system'
  }.freeze
  
  # Validations
  validates :content, presence: true
  validates :notification_type, inclusion: { in: NOTIFICATION_TYPES.values }
  validates :read, inclusion: { in: [true, false] }
  
  # Polymorphic relationship to resource
  belongs_to :resource, polymorphic: true, optional: true
  
  # Scopes
  scope :unread, -> { where(read: false) }
  scope :read, -> { where(read: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :of_type, ->(type) { where(notification_type: type) }
  
  # Callbacks
  before_validation :set_defaults
  
  # Mark as read
  def mark_as_read!
    update(read: true)
  end
  
  # Mark as unread
  def mark_as_unread!
    update(read: false)
  end
  
  private
  
  # Set default values
  def set_defaults
    self.read ||= false
  end
end
