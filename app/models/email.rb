class Email < ApplicationRecord
  acts_as_tenant(:organization)

  belongs_to :customer
  belongs_to :user
  has_one_attached :raw_message
  has_many_attached :attachments

  validates :message_id, presence: true, uniqueness: true
  validates :from_email, :to_email, presence: true

  scope :sent, -> { where(status: "sent") }
  scope :received, -> { where(status: "received") }
  scope :unread, -> { where(read_at: nil).where(status: "received") }
  scope :recent, -> { order(created_at: :desc) }
  scope :opened, -> { where(status: "sent").where.not(first_opened_at: nil) }
  scope :unopened, -> { where(status: "sent", first_opened_at: nil) }

  before_create :assign_tracking_token, if: :should_track_opens?

  # Records a tracking pixel hit. Stamps the first open, bumps the counter,
  # updates last_opened_at. Idempotent enough to handle Gmail's image-proxy
  # prefetch firing the pixel repeatedly.
  def record_open!
    now = Time.current
    Email.where(id: id).update_all([
      "first_opened_at = COALESCE(first_opened_at, ?), last_opened_at = ?, open_count = open_count + 1, updated_at = ?",
      now, now, now
    ])
    reload
  end

  def opened?
    first_opened_at.present?
  end

  # Check if this is a received email
  def received?
    status == "received"
  end

  # Check if this is a sent email
  def sent?
    status == "sent"
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

  # Check if this email has actual downloadable attachments (not just flagged)
  def has_downloadable_attachments?
    attachments.any?
  end

  # Get the count of actual attachments
  def attachments_count
    attachments.count
  end

  # Serialize attachments for JSON responses
  def attachments_json
    attachments.map do |attachment|
      {
        id: attachment.id,
        filename: attachment.filename.to_s,
        content_type: attachment.content_type,
        byte_size: attachment.byte_size,
        human_size: ActiveSupport::NumberHelper.number_to_human_size(attachment.byte_size),
        download_url: Rails.application.routes.url_helpers.rails_blob_path(attachment, disposition: "attachment", only_path: true),
        created_at: attachment.created_at
      }
    end
  end

  private

  # Outbound emails get a tracking pixel; inbound emails are someone else's
  # message and we don't rewrite their bodies.
  def should_track_opens?
    status.to_s == "sent"
  end

  def assign_tracking_token
    self.tracking_token ||= SecureRandom.urlsafe_base64(24)
  end
end
