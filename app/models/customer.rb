class Customer < ApplicationRecord
  belongs_to :user, optional: true
  has_one :customer_location, dependent: :destroy
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
  after_save :analyze_phone_number, if: -> { phone.present? && should_analyze_phone? }
  after_save :track_meta_conversions_events
  after_create :calculate_lead_score
  
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
    'WA' => 'WA',
    'Qatar_Web_summit' => 'Qatar_Web_summit',
    'Leap' => 'Leap',
    'Gitex' => 'Gitex',
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
    if self.customer_location.present? && self.customer_location.timezone.present?
      tz = ActiveSupport::TimeZone.find_tzinfo(self.customer_location.timezone)
      Time.current.in_time_zone(tz)
    else
      nil
    end
  end
  
  # Analyze the customer's phone number using comprehensive phone location services
  def analyze_phone_number
    return false unless phone.present?
    
    Rails.logger.info("Queuing comprehensive phone analysis for customer #{id} (#{name}) with phone #{phone}")
    
    # Enqueue the background job to analyze the phone number with new services
    job_id = EnhancedPhoneAnalysisWorker.perform_async(id)
    
    if job_id
      Rails.logger.info("Successfully queued enhanced phone analysis job #{job_id} for customer #{id}")
      true
    else
      Rails.logger.error("Failed to queue enhanced phone analysis job for customer #{id}")
      false
    end
  rescue => e
    Rails.logger.error("Error queueing enhanced phone analysis for customer #{id}: #{e.message}")
    false
  end
  
  # Determine if phone analysis should be performed
  def should_analyze_phone?
    # Always analyze if no location record exists
    return true unless customer_location.present?
    
    # Re-analyze if phone number changed
    return true if saved_change_to_phone?
    
    # Re-analyze if using old analysis version
    return true if customer_location.analysis_version != '2.0'
    
    # Re-analyze if analysis is older than 30 days (for accuracy improvements)
    return true if customer_location.analyzed_at < 30.days.ago
    
    false
  end
  
  # Force re-analysis of phone number (for manual triggers)
  def force_phone_analysis!
    return false unless phone.present?
    
    Rails.logger.info("Force analyzing phone number for customer #{id} (#{name})")
    analyze_phone_number
  end
  
  # Update customer with comprehensive phone analysis data using new location table
  def update_from_phone_analysis(analysis_data)
    return false unless analysis_data[:success]
    
    begin
      # Create/update the customer location record
      CustomerLocation.create_from_analysis(self, analysis_data)
      
      # Update basic customer fields that should remain in customer table
      data = analysis_data[:data]
      basic_updates = {
        country: data[:country] || country,
        timezone: data[:timezone] || timezone,
        phone_analysis_completed_at: Time.current,
        phone_analysis_version: '2.0'
      }
      
      # Only update non-blank values to preserve existing data
      basic_updates = basic_updates.select { |k, v| v.present? || self[k].blank? }
      update!(basic_updates)
      
      Rails.logger.info("Successfully updated customer #{id} with enhanced phone analysis data (v2.0)")
      true
    rescue => e
      Rails.logger.error("Error updating customer #{id} with phone analysis data: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      false
    end
  end
  
  # Delegate location methods to customer_location
  def location_summary
    customer_location&.location_summary || [city, state, country].compact.join(', ')
  end
  
  def current_location_time
    customer_location&.current_time || current_time_in_timezone
  end
  
  def location_coordinates
    return nil unless customer_location&.coordinates_available?
    { lat: customer_location.latitude, lng: customer_location.longitude }
  end
  
  def detailed_timezone_info
    return nil unless customer_location
    {
      timezone: customer_location.timezone,
      abbreviation: customer_location.timezone_abbreviation,
      offset: customer_location.timezone_offset,
      dst_active: customer_location.dst_active,
      current_time: customer_location.current_time
    }
  end
  
  def phone_analysis_confidence
    return nil unless customer_location
    {
      location: customer_location.location_confidence,
      timezone: customer_location.timezone_confidence,
      overall: (customer_location.location_confidence + customer_location.timezone_confidence) / 2
    }
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

  def calculate_lead_score
    scoring_service = LeadScoringService.new(self)
    scoring_service.calculate_score
  end

  def lead_score_color
    return 'text-gray-500' unless lead_score
    
    case lead_score
    when 80..100 then 'text-green-600 font-bold'
    when 60..79 then 'text-green-500'
    when 40..59 then 'text-yellow-600'
    when 20..39 then 'text-orange-600'
    else 'text-red-600'
    end
  end
  
  def lead_score_badge
    return 'N/A' unless lead_score
    
    case lead_score
    when 80..100 then 'Excellent'
    when 60..79 then 'Good'
    when 40..59 then 'Fair'
    when 20..39 then 'Poor'
    else 'Very Poor'
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
    self.repeat_lead = false if repeat_lead.nil?
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

  # Track Meta Conversions API events based on customer lifecycle changes
  def track_meta_conversions_events
    return if skip_meta_tracking? # Skip during seeds, tests, etc.

    # Track lead creation
    if saved_change_to_id? # New customer created
      MetaConversionsApiWorker.perform_async(id, 'lead')
    end

    # Track contact establishment
    if saved_change_to_status? && status == 'Contact Established'
      MetaConversionsApiWorker.perform_async(id, 'complete_registration')
    end

    # Track conversion
    if saved_change_to_status? && status == 'Converted'
      MetaConversionsApiWorker.perform_async(id, 'purchase')
    end

    # Track proposal sent
    if saved_change_to_status? && status == 'Proposal Sent'
      MetaConversionsApiWorker.perform_async(id, 'initiate_checkout')
    end

    # Track communication status changes
    track_communication_events if communication_status_changed?

    # Track profile completion
    if profile_completion_improved?
      MetaConversionsApiWorker.perform_async(id, 'complete_registration')
    end
  end

  def skip_meta_tracking?
    # Skip tracking during tests, seeds, or if specifically disabled
    Rails.env.test? || 
    defined?(Rails::Console) || 
    Thread.current[:skip_meta_tracking] == true
  end

  def communication_status_changed?
    saved_change_to_call_status? || 
    saved_change_to_email_status? || 
    saved_change_to_whatsapp_status? || 
    saved_change_to_linkedin_status?
  end

  def track_communication_events
    if saved_change_to_call_status? && call_status == 'Connected'
      MetaConversionsApiWorker.perform_async(id, 'contact', { 'communication_type' => 'phone' })
    end

    if saved_change_to_email_status? && email_status == 'Connected'
      MetaConversionsApiWorker.perform_async(id, 'contact', { 'communication_type' => 'email' })
    end

    if saved_change_to_whatsapp_status? && whatsapp_status == 'Connected'
      MetaConversionsApiWorker.perform_async(id, 'contact', { 'communication_type' => 'whatsapp' })
    end

    if saved_change_to_linkedin_status? && linkedin_status == 'Conversation Initiated'
      MetaConversionsApiWorker.perform_async(id, 'contact', { 'communication_type' => 'linkedin' })
    end
  end

  def profile_completion_improved?
    # Check if important fields were added that improve profile completeness
    return false unless persisted?
    
    important_fields = [:email, :phone, :company, :country, :project_type]
    important_fields.any? do |field|
      saved_change_to_attribute?(field) && send(field).present? && send("#{field}_was").blank?
    end
  end
  
end
