class Customer < ApplicationRecord
  belongs_to :user, optional: true
  has_many :deals
  has_many :recordings, dependent: :destroy
  has_many :customer_activities, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :whatsapp_messages, dependent: :destroy
  has_many :emails, dependent: :destroy
  has_many_attached :documents

  # Remove single file attachment as we're using documents now
  #has_one_attached :file
  
  validates :name, presence: { message: "is required" }
  validates :email, uniqueness: { case_sensitive: false, allow_blank: true },
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address", allow_blank: true }
  validates :phone, format: { with: /\A\+\d{6,15}\z/, message: "must be a valid phone number with country code (e.g. +923001234567)", allow_blank: true }
  
  # Validate document types
  validate :acceptable_documents
  
  before_validation :normalize_email
  before_validation :normalize_phone
  before_validation :set_default_values
  before_save :set_exhaust_date, if: -> { status_changed? && status == 'Exhausted' }
  before_save :sync_whatsapp_status, if: -> { call_status_changed? && call_status == 'Incorrect Number' }
  before_save :sync_whatsapp_chat_id, if: -> { phone_changed? && phone.present? }
  before_save :record_activity_changes
  after_save :create_task_on_user_assignment, if: -> { saved_change_to_user_id? && user_id.present? }
  after_save :notify_user_of_assignment, if: -> { saved_change_to_user_id? && user_id.present? }
  after_save :analyze_phone_number, if: -> { phone.present? }
  
  # Constants for dropdown fields
  CUSTOMER_TYPES = {
    'Standard' => 'Standard',
    'High Value' => 'High Value'
  }.freeze

  LEAD_SOURCES = {
    'Upwork' => 'Upwork',
    'LinkedIn' => 'LinkedIn',
    'Email Marketing' => 'Email Marketing',
    'Social Media Platforms' => 'Social Media Platforms',
    'Website' => 'Website',
    'CCR' => 'CCR',
    'Inbound' => 'Inbound',
    'Inbound_1' => 'Inbound_1',
    'Inbound_2' => 'Inbound_2',
    'Inbound_3' => 'Inbound_3',
    'WA' => 'WA'
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
    'Invalid' => 'Invalid',
    'Retarget' => 'Retarget',
    'Exhausted_1' => 'Exhausted_1'
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
  validates :customer_type, inclusion: { in: CUSTOMER_TYPES.values }
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
  
  # Analyze the customer's phone number using DeepSeek to identify country, timezone, and preferred calling time
  def analyze_phone_number
    return false unless phone.present?

    return false if preferred_calling_time.present? && preferred_calling_time.downcase != 'not applicable'
    
    Rails.logger.info("Queuing phone analysis for customer #{id} (#{name}) with phone #{phone}")
    
    # Enqueue the background job to analyze the phone number
    job_id = CustomerPhoneAnalysisWorker.perform_async(id)
    
    if job_id
      Rails.logger.info("Successfully queued phone analysis job #{job_id} for customer #{id}")
      true
    else
      Rails.logger.error("Failed to queue phone analysis job for customer #{id}")
      false
    end
  rescue => e
    Rails.logger.error("Error queueing phone analysis for customer #{id}: #{e.message}")
    false
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
  
  # Check if current time matches the preferred calling time
  def is_preferred_calling_time?
    return false unless preferred_calling_time.present? && preferred_calling_time != 'Not Applicable'
    return false unless current_time = current_time_in_timezone
    
    # Current time details
    current_hour = current_time.hour
    current_day = current_time.strftime("%A").downcase # "monday", "tuesday", etc.
    current_weekday = !current_time.saturday? && !current_time.sunday? # Is it a weekday?
    
    # Extract days of week if specified in parentheses
    day_constraints = []
    if preferred_calling_time =~ /\(([^)]+)\)/
      day_part = $1.downcase
      # Check for common day patterns
      if day_part.include?("weekday") || day_part.include?("week day")
        day_constraints = %w[monday tuesday wednesday thursday friday]
      elsif day_part.include?("weekend")
        day_constraints = %w[saturday sunday]
      elsif day_part.include?("monday to friday") || day_part.include?("mon to fri")
        day_constraints = %w[monday tuesday wednesday thursday friday]
      elsif day_part =~ /([a-zA-Z]+)\s+to\s+([a-zA-Z]+)/i
        start_day = $1.downcase
        end_day = $2.downcase
        all_days = %w[monday tuesday wednesday thursday friday saturday sunday]
        start_idx = all_days.index(start_day)
        end_idx = all_days.index(end_day)
        if start_idx && end_idx
          # Handle both normal ranges (mon-fri) and wrap-around ranges (fri-tue)
          if start_idx <= end_idx
            day_constraints = all_days[start_idx..end_idx]
          else
            day_constraints = all_days[start_idx..-1] + all_days[0..end_idx]
          end
        end
      else
        # Check for individual days mentioned
        %w[monday tuesday wednesday thursday friday saturday sunday].each do |day|
          day_constraints << day if day_part.include?(day)
        end
      end
    end
    
    # If day constraints exist and current day doesn't match, return false
    if day_constraints.any? && !day_constraints.include?(current_day)
      return false
    end
    
    # Clean the time part by removing day constraints if they exist
    time_part = preferred_calling_time.gsub(/\s*\([^)]+\)/, '').strip
    
    # Case 1: Range like "10 AM - 6 PM PKT" or "9AM-11AM"
    if time_part =~ /(\d{1,2})\s*([AaPp][Mm])(?:\s*(?:[-–—])\s*)(\d{1,2})\s*([AaPp][Mm])(?:\s*([A-Za-z]{3,})?)?/
      start_hour = $1.to_i
      start_ampm = $2.upcase
      end_hour = $3.to_i
      end_ampm = $4.upcase
      
      # Convert to 24-hour format
      start_hour = start_hour % 12
      start_hour += 12 if start_ampm == "PM"
      
      end_hour = end_hour % 12
      end_hour += 12 if end_ampm == "PM"
      
      # Check if current hour is within range
      if start_hour <= end_hour
        return current_hour >= start_hour && current_hour <= end_hour
      else
        # Handle overnight ranges like "10 PM - 2 AM"
        return current_hour >= start_hour || current_hour <= end_hour
      end
    
    # Case 2: Morning, Afternoon, Evening, Night
    elsif time_part =~ /morning/i
      return current_hour >= 7 && current_hour < 12
    elsif time_part =~ /afternoon/i
      return current_hour >= 12 && current_hour < 17
    elsif time_part =~ /evening/i
      return current_hour >= 17 && current_hour < 21
    elsif time_part =~ /night/i
      return current_hour >= 21 || current_hour < 7
      
    # Case 3: Simple time like "9 AM PKT" or "9 PM"
    elsif time_part =~ /(\d{1,2})\s*([AaPp][Mm])(?:\s*([A-Za-z]{3,})?)?/
      hour = $1.to_i
      ampm = $2.upcase
      
      # Convert to 24-hour format
      hour = hour % 12
      hour += 12 if ampm == "PM"
      
      # Allow a 1-hour window around the specified time
      return (current_hour >= hour - 1) && (current_hour <= hour)
    end
    
    # Default: no match found
    false
  end
  
  # Fetch and store WhatsApp messages
  def fetch_and_store_whatsapp_messages
    return [] if whatsapp_chat_id.blank?
    
    # Create a new instance of the WhatsApp API service
    whatsapp_service = Whatsapp::ApiService.new
    
    # Skip if credentials not configured
    return [] unless whatsapp_service.credentials_configured?
    
    Rails.logger.info("Fetching WhatsApp messages from API for customer #{id} (#{name})")
    
    # Get the messages for this chat
    response = whatsapp_service.get_chat_room(whatsapp_chat_id)
    
    # Return empty array if API call was not successful
    if !response[:success] || !response[:data] || !response[:data][:data]
      Rails.logger.error("API call to get WhatsApp messages failed for customer #{id}: #{response[:error]}")
      return []
    end
    
    # Log the number of messages received
    message_count = response[:data][:data].size
    Rails.logger.info("Received #{message_count} WhatsApp messages from API for customer #{id}")
    
    # Import messages into the database
    stored_messages = WhatsappMessage.import_messages(self, response[:data][:data])
    
    Rails.logger.info("Successfully stored #{stored_messages.size} WhatsApp messages in database for customer #{id}")
    
    # Return the WhatsApp messages from the database to ensure we're using the stored versions
    whatsapp_messages.ordered
  end
  
  # Get all WhatsApp messages for this customer from the database
  # If force_refresh is true, it will fetch from API first
  def get_whatsapp_messages(force_refresh: false)
    if force_refresh || whatsapp_messages.count == 0
      fetch_and_store_whatsapp_messages
    end
    
    whatsapp_messages.ordered
  end
  
  def document_types
    documents.map do |doc|
      case doc.content_type
      when /pdf/i then :pdf
      when /word|docx|doc/i then :doc
      when /excel|xlsx|xls|csv/i then :spreadsheet
      when /image/i then :image
      else :other
      end
    end
  end
  
  private
  
  def acceptable_documents
    return unless documents.attached?

    documents.each do |document|
      unless document.content_type.in?(%w[
        application/pdf
        application/msword
        application/vnd.openxmlformats-officedocument.wordprocessingml.document
        application/vnd.ms-excel
        application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
        text/csv
        image/jpeg
        image/png
        image/gif
      ])
        errors.add(:documents, "must be a PDF, Word, Excel, CSV, or image file")
      end

      if document.byte_size > 10.megabytes
        errors.add(:documents, "size should be less than 10MB")
      end
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
    self.customer_type ||= 'Standard'
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
  
  def sync_whatsapp_chat_id
    # Format the phone number for WhatsApp chat ID
    phone_without_plus = phone.gsub(/\A\+/, '')
    self.whatsapp_chat_id = "#{phone_without_plus}@c.us"
  end
  
  def record_activity_changes
    return if new_record? # Skip for new records
    
    # Track changes to important fields
    tracked_fields = %w[status call_status email_status whatsapp_status linkedin_status user_id preferred_calling_time]
    
    changes_to_track = self.changes.select { |field, _| tracked_fields.include?(field) }
    
    changes_to_track.each do |field, (old_value, new_value)|
      # For user_id field, get the actual user names instead of IDs
      if field == 'user_id'
        old_user_name = old_value.present? ? User.find_by(id: old_value)&.name || 'Unknown' : 'None'
        new_user_name = new_value.present? ? User.find_by(id: new_value)&.name || 'Unknown' : 'None'
        
        customer_activities.build(
          action: "User assigned",
          details: "Changed from '#{old_user_name}' to '#{new_user_name}'",
          user_id: self.user_id || User.first&.id # Assign to current user or first user as fallback
        )
      else
        customer_activities.build(
          action: "#{field.humanize} changed",
          details: "Changed from '#{old_value}' to '#{new_value}'",
          user_id: self.user_id || User.first&.id # Assign to current user or first user as fallback
        )
      end
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
  
  # Create a notification and send an email when a customer is assigned to a user
  def notify_user_of_assignment
    # Skip if no user is assigned
    return unless user_id.present?
    
    # Queue the notification job
    CustomerAssignmentNotificationWorker.perform_async(user_id, id)
  end
  
  # Queue phone analysis when phone number is added or changed
  def queue_phone_analysis
    analyze_phone_number
  end
end
