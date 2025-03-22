class Customer < ApplicationRecord
  belongs_to :user, optional: true
  has_many :deals
  has_many :recordings, dependent: :destroy
  has_many :customer_activities, dependent: :destroy
  has_many :tasks, dependent: :destroy
  
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
  after_save :create_task_on_user_assignment, if: -> { saved_change_to_user_id? && user_id.present? }
  
  # Constants for dropdown fields
  LEAD_SOURCES = {
    'Upwork' => 'Upwork',
    'LinkedIn' => 'LinkedIn',
    'Email Marketing' => 'Email Marketing',
    'Social Media Platforms' => 'Social Media Platforms',
    'Website' => 'Website',
    'CCR' => 'CCR',
    'Inbound' => 'Inbound'
  }.freeze
  
  PROJECT_TYPES = {
    'Mobile App' => 'Mobile App',
    'Web App' => 'Web App',
    'Chrome Extension' => 'Chrome Extension',
    'Smart Watch' => 'Smart Watch',
    'TV App' => 'TV App',
    'Not Applicable' => 'Not Applicable'
  }.freeze
  
  PLATFORMS = {
    'Mobile App' => 'Mobile App',
    'Web App' => 'Web App',
    'Web and Mobile App' => 'Web and Mobile App',
    'AI App' => 'AI App',
    'Smart Watch' => 'Smart Watch',
    'Frontend' => 'Frontend',
    'Not Applicable' => 'Not Applicable',
  }.freeze
  
  PROJECT_SCOPES = {
    'Lean-Launch-MVP' => 'Lean-Launch-MVP',
    'Enterprise-Scale' => 'Enterprise-Scale',
    'Growth-Ready' => 'Growth-Ready',
    'Not Applicable' => 'Not Applicable'
  }.freeze
  
  STATUSES = {
    'Pending' => 'Pending',
    'Contact Established' => 'Contact Established',
    'Contact Not Established' => 'Contact Not Established',
    'Unresponsive' => 'Unresponsive',
    'Converted' => 'Converted',
    'Proposal Sent' => 'Proposal Sent',
    'Not Interested' => 'Not Interested',
    'Exhausted' => 'Exhausted',
    'Invalid' => 'Invalid'
  }.freeze
  
  CALL_STATUSES = {
    'Pending' => 'Pending',
    'Called' => 'Called',
    'Followup' => 'Followup',
    'Incorrect Number' => 'Incorrect Number',
    'Connected' => 'Connected',
    'Not Applicable' => 'Not Applicable'
  }.freeze
  
  EMAIL_STATUSES = {
    'Pending' => 'Pending',
    'Email Sent' => 'Email Sent',
    'Followup' => 'Followup',
    'Incorrect Email' => 'Incorrect Email',
    'Connected' => 'Connected',
    'Not Applicable' => 'Not Applicable'
  }.freeze
  
  WHATSAPP_STATUSES = {
    'Pending' => 'Pending',
    'Message Sent' => 'Message Sent',
    'Followup' => 'Followup',
    'Incorrect Number' => 'Incorrect Number',
    'Connected' => 'Connected',
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
  validates :platform, inclusion: { in: PLATFORMS.values }, allow_blank: true
  validates :project_scope, inclusion: { in: PROJECT_SCOPES.values }, allow_blank: true
  
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
  
  # Returns the current time in the customer's timezone
  def current_time_in_timezone
    return nil unless timezone.present? || country.present?

    tz = if timezone.present?
      # Validate timezone before using it
      begin
        # Try to ensure it's a valid timezone identifier
        valid_tz = ActiveSupport::TimeZone.find_tzinfo(timezone) rescue nil
        valid_tz ? timezone : 'UTC'
      rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier
        # Fallback to country-based timezone if the timezone is invalid
        nil
      end
    end

    # If timezone is invalid or not present, use country-based fallback
    if tz.nil?
      # Fallback to country-based timezone
      country_code = country&.strip&.upcase
      
      case country_code
      # North America
      when 'UNITED STATES', 'USA', 'US'
        'America/New_York'
      when 'CANADA', 'CA'
        'America/Toronto'
      when 'MEXICO', 'MX'
        'America/Mexico_City'
        
      # Europe
      when 'UNITED KINGDOM', 'UK', 'GB'
        'Europe/London'
      when 'IRELAND', 'IE'
        'Europe/Dublin'
      when 'PORTUGAL', 'PT'
        'Europe/Lisbon'
      when 'GERMANY', 'DE'
        'Europe/Berlin'
      when 'FRANCE', 'FR'
        'Europe/Paris'
      when 'SPAIN', 'ES'
        'Europe/Madrid'
      when 'ITALY', 'IT'
        'Europe/Rome'
      when 'NETHERLANDS', 'NL'
        'Europe/Amsterdam'
      when 'BELGIUM', 'BE'
        'Europe/Brussels'
      when 'SWITZERLAND', 'CH'
        'Europe/Zurich'
      when 'AUSTRIA', 'AT'
        'Europe/Vienna'
      when 'SWEDEN', 'SE'
        'Europe/Stockholm'
      when 'NORWAY', 'NO'
        'Europe/Oslo'
      when 'DENMARK', 'DK'
        'Europe/Copenhagen'
      when 'FINLAND', 'FI'
        'Europe/Helsinki'
        
      # Asia
      when 'PAKISTAN', 'PK'
        'Asia/Karachi'
      when 'INDIA', 'IN'
        'Asia/Kolkata'
      when 'BANGLADESH', 'BD'
        'Asia/Dhaka'
      when 'SRI LANKA', 'LK'
        'Asia/Colombo'
      when 'JAPAN', 'JP'
        'Asia/Tokyo'
      when 'SOUTH KOREA', 'KR'
        'Asia/Seoul'
      when 'CHINA', 'CN'
        'Asia/Shanghai'
      when 'TAIWAN', 'TW'
        'Asia/Taipei'
      when 'HONG KONG', 'HK'
        'Asia/Hong_Kong'
      when 'SINGAPORE', 'SG'
        'Asia/Singapore'
      when 'MALAYSIA', 'MY'
        'Asia/Kuala_Lumpur'
      when 'THAILAND', 'TH'
        'Asia/Bangkok'
      when 'INDONESIA', 'ID'
        'Asia/Jakarta'
      when 'PHILIPPINES', 'PH'
        'Asia/Manila'
      when 'VIETNAM', 'VN'
        'Asia/Ho_Chi_Minh'
        
      # Middle East
      when 'UNITED ARAB EMIRATES', 'UAE', 'AE'
        'Asia/Dubai'
      when 'SAUDI ARABIA', 'SA'
        'Asia/Riyadh'
      when 'QATAR', 'QA'
        'Asia/Qatar'
      when 'KUWAIT', 'KW'
        'Asia/Kuwait'
      when 'BAHRAIN', 'BH'
        'Asia/Bahrain'
      when 'OMAN', 'OM'
        'Asia/Muscat'
      when 'ISRAEL', 'IL'
        'Asia/Jerusalem'
        
      # Oceania
      when 'AUSTRALIA', 'AU'
        'Australia/Sydney'
      when 'NEW ZEALAND', 'NZ'
        'Pacific/Auckland'
        
      # Africa
      when 'SOUTH AFRICA', 'ZA'
        'Africa/Johannesburg'
      when 'EGYPT', 'EG'
        'Africa/Cairo'
      when 'NIGERIA', 'NG'
        'Africa/Lagos'
      when 'KENYA', 'KE'
        'Africa/Nairobi'
        
      # Default
      else
        'UTC'
      end
    end
    Time.current.in_time_zone(tz)
  rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier => e
    # Handle invalid timezone by returning nil
    Rails.logger.warn("Invalid timezone for customer #{id}: #{e.message}")
    nil
  end
  
  # Follow-up methods
  def schedule_followup(followup_date, notes, user, add_to_calendar = true)
    return false unless user.present?
    
    # If the user has Google Calendar configured and add_to_calendar is true, use that
    if user.google_auth_configured? && add_to_calendar
      user.schedule_customer_followup(self, followup_date, notes)
    else
      # Just create a task without Google Calendar integration
      update(followup_date: followup_date, followup_notes: notes)
      
      Task.create!(
        user: user,
        customer: self,
        title: "Follow up with #{name}",
        description: notes,
        due_date: followup_date,
        priority: 'Medium',
        status: 'pending'
      )
      
      true
    end
  end
  
  def has_pending_followup?
    followup_date.present? && followup_date > Time.current
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
    self.preferred_calling_time ||= 'Not Applicable'
    self.platform ||= 'Not Applicable'
    self.project_scope ||= 'Not Applicable'
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
    tracked_fields = %w[status call_status email_status whatsapp_status linkedin_status user_id preferred_calling_time]
    
    changes_to_track = self.changes.select { |field, _| tracked_fields.include?(field) }
    
    changes_to_track.each do |field, (old_value, new_value)|
      customer_activities.build(
        action: "#{field.humanize} changed",
        details: "Changed from '#{old_value}' to '#{new_value}'",
        user_id: self.user_id || User.first&.id # Assign to current user or first user as fallback
      )
    end
  end
  
  # Create a task when a customer is assigned to a user
  def create_task_on_user_assignment
    Task.create!(
      title: "Follow up with new customer: #{name}",
      description: "Contact new customer #{name} (#{company}) and establish connection.",
      due_date: Time.current + 1.day,
      status: 'pending',
      priority: 'High',
      user_id: user_id,
      customer_id: id
    )
  end
end
