class Customer < ApplicationRecord
  belongs_to :user, optional: true
  has_many :deals
  has_many :recordings, dependent: :nullify
  has_many :customer_activities, dependent: :destroy
  
  # Add file attachment capability
  has_one_attached :file
  
  validates :name, presence: { message: "is required" }
  validates :email, uniqueness: { case_sensitive: false, allow_blank: true },
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address", allow_blank: true }
  validates :phone, format: { with: /\A\+\d{6,15}\z/, message: "must be a valid phone number with country code (e.g. +923001234567)", allow_blank: true }
  
  # Validate file type
  validate :acceptable_file
  
  before_validation :normalize_email
  before_validation :normalize_phone
  before_validation :set_default_values
  before_save :set_exhaust_date, if: -> { status_changed? && status == 'Exhausted' }
  before_save :sync_whatsapp_status, if: -> { call_status_changed? && call_status == 'Incorrect Number' }
  before_save :record_activity_changes
  
  # Constants for dropdown fields
  LEAD_SOURCES = {
    'Upwork' => 'Upwork',
    'LinkedIn' => 'LinkedIn',
    'Email Marketing' => 'Email Marketing',
    'Social Media Platforms' => 'Social Media Platforms',
    'Website' => 'Website',
    'CCR' => 'CCR'
  }.freeze
  
  PROJECT_TYPES = {
    'Mobile App' => 'Mobile App',
    'Web App' => 'Web App',
    'Chrome Extension' => 'Chrome Extension',
    'Smart Watch' => 'Smart Watch',
    'TV App' => 'TV App',
    'Not Applicable' => 'Not Applicable'
  }.freeze
  
  STATUSES = {
    'Pending' => 'Pending',
    'Connection Established' => 'Connection Established',
    'Connection Not Established' => 'Connection Not Established',
    'Not Interested' => 'Not Interested',
    'Exhausted' => 'Exhausted'
  }.freeze
  
  CALL_STATUSES = {
    'Pending' => 'Pending',
    'Called' => 'Called',
    'Followup' => 'Followup',
    'Incorrect Number' => 'Incorrect Number',
    'Call Connected' => 'Call Connected',
    'Not Applicable' => 'Not Applicable'
  }.freeze
  
  EMAIL_STATUSES = {
    'Pending' => 'Pending',
    'Email Sent' => 'Email Sent',
    'Followup' => 'Followup',
    'Incorrect Email' => 'Incorrect Email',
    'Conversation Initiated' => 'Conversation Initiated',
    'Not Applicable' => 'Not Applicable'
  }.freeze
  
  WHATSAPP_STATUSES = {
    'Pending' => 'Pending',
    'WhatsApp Message Sent' => 'WhatsApp Message Sent',
    'Followup' => 'Followup',
    'Incorrect Number' => 'Incorrect Number',
    'Conversation Initiated' => 'Conversation Initiated',
    'Not Applicable' => 'Not Applicable'
  }.freeze
  
  LINKEDIN_STATUSES = {
    'Pending' => 'Pending',
    'Message Sent' => 'Message Sent',
    'Followup' => 'Followup',
    'Conversation Initiated' => 'Conversation Initiated',
    'Not Applicable' => 'Not Applicable'
  }.freeze
  
  UPWORK_PROFILES = {
    'Taha' => 'Taha',
    'Arham' => 'Arham',
    'Sarmad' => 'Sarmad',
    'Tecaudex' => 'Tecaudex',
    'Not Applicable' => 'Not Applicable'
  }.freeze
  
  EXHAUST_STATUSES = {
    'NA' => 'NA',
    'Exhausted' => 'Exhausted',
    'Not Applicable' => 'Not Applicable'
  }.freeze
  
  # Validations for dropdown fields
  validates :lead_source, inclusion: { in: LEAD_SOURCES.values }, allow_blank: true
  validates :project_type, inclusion: { in: PROJECT_TYPES.values }, allow_blank: true
  validates :status, inclusion: { in: STATUSES.values }, allow_blank: true
  validates :call_status, inclusion: { in: CALL_STATUSES.values }, allow_blank: true
  validates :email_status, inclusion: { in: EMAIL_STATUSES.values }, allow_blank: true
  validates :whatsapp_status, inclusion: { in: WHATSAPP_STATUSES.values }, allow_blank: true
  validates :linkedin_status, inclusion: { in: LINKEDIN_STATUSES.values }, allow_blank: true
  validates :upwork_profile, inclusion: { in: UPWORK_PROFILES.values }, allow_blank: true
  validates :exhaust_status, inclusion: { in: EXHAUST_STATUSES.values }, allow_blank: true
  
  # Scopes
  scope :assigned_to, ->(user_id) { where(user_id: user_id) if user_id.present? }
  scope :search, ->(term) {
    if term.present?
      term = "%#{term.downcase}%"
      where(
        "LOWER(name) LIKE ? OR LOWER(email) LIKE ? OR LOWER(phone) LIKE ? OR LOWER(company) LIKE ?",
        term, term, term, term
      )
    end
  }
  
  # Returns the count of active deals for this customer
  def active_deals_count
    deals.active.count
  end
  
  private
  
  def acceptable_file
    return unless file.attached?
    
    unless file.blob.content_type.in?(%w[
      image/jpeg image/jpg image/png image/gif
      application/pdf
      application/msword
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
    ])
      errors.add(:file, 'must be a JPEG, PNG, GIF, PDF, DOC or DOCX file')
    end
    
    if file.blob.byte_size > 10.megabytes
      errors.add(:file, 'size cannot exceed 10MB')
    end
  end
  
  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
  
  def normalize_phone
    if phone.present?
      # First, strip any whitespace
      cleaned_phone = phone.strip
      
      # Check if the phone already has a plus sign
      has_plus = cleaned_phone.start_with?('+')
      
      # Remove all non-digit characters
      digits_only = cleaned_phone.gsub(/\D/, '')
      
      # Add the plus sign back if it was there, or add it if it wasn't
      self.phone = '+' + digits_only
      
      # Log the normalized phone number for debugging
      Rails.logger.debug("Phone normalized from '#{phone}' to '#{self.phone}'")
    end
  end
  
  def set_default_values
    self.exhaust_status ||= 'NA'
    self.status ||= 'Pending'
    self.call_status ||= 'Pending'
    self.email_status ||= 'Pending'
    self.whatsapp_status ||= 'Pending'
    self.linkedin_status ||= 'Pending'
    self.project_type ||= 'Not Applicable'
    self.upwork_profile ||= 'Not Applicable'
  end
  
  def set_exhaust_date
    self.exhaust_date = Time.current
  end
  
  def sync_whatsapp_status
    self.whatsapp_status = 'Incorrect Number' if call_status == 'Incorrect Number'
  end
  
  def record_activity_changes
    return if new_record? # Skip for new records
    
    # Track changes to important fields
    tracked_fields = %w[status call_status email_status whatsapp_status linkedin_status user_id]
    
    changes_to_track = self.changes.select { |field, _| tracked_fields.include?(field) }
    
    changes_to_track.each do |field, (old_value, new_value)|
      customer_activities.build(
        action: "#{field.humanize} changed",
        details: "Changed from '#{old_value}' to '#{new_value}'",
        user_id: self.user_id || User.first&.id # Assign to current user or first user as fallback
      )
    end
  end
end
