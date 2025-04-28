class Email < ApplicationRecord
  belongs_to :customer
  belongs_to :user
  has_many :email_attachments, dependent: :destroy
  has_one_attached :raw_message
  
  validates :message_id, presence: true, uniqueness: true
  validates :from_email, :to_email, presence: true
  
  scope :sent, -> { where(status: 'sent') }
  scope :received, -> { where(status: 'received') }
  scope :unread, -> { where(read_at: nil).where(status: 'received') }
  scope :recent, -> { order(created_at: :desc) }
  
  # Check if this is a received email
  def received?
    status == 'received'
  end
  
  # Check if this is a sent email
  def sent?
    status == 'sent'
  end
  
  # Mark the email as read
  def mark_as_read!
    update(read_at: Time.current) if read_at.nil?
  end
  
  # Format the email for display
  def formatted_date
    (sent_at || received_at || created_at).strftime("%b %d, %Y at %I:%M %p")
  end
  
  # Get a suitable subject line with a fallback
  def display_subject
    subject.present? ? subject : "(No Subject)"
  end
  
  # Get the sender's name or email
  def sender_name
    from_name.present? ? from_name : from_email
  end
  
  # Get the receiver's name or email
  def receiver_name
    to_name.present? ? to_name : to_email
  end
end 