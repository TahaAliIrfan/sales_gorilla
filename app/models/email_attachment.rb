class EmailAttachment < ApplicationRecord
  belongs_to :email
  has_one_attached :file
  
  validates :filename, presence: true
  validates :attachment_id, presence: true, uniqueness: true
  
  # Check if attachment is an image
  def image?
    content_type.to_s.start_with?('image/')
  end
  
  # Check if attachment is a PDF
  def pdf?
    content_type.to_s == 'application/pdf'
  end
  
  # Get a human-readable file size
  def human_size
    ActiveSupport::NumberHelper.number_to_human_size(size)
  end
end 