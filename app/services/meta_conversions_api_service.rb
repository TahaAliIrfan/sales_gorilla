require 'net/http'
require 'uri'
require 'json'
require 'digest'

class MetaConversionsApiService
  attr_reader :pixel_id, :access_token

  def initialize
    @pixel_id = Rails.application.credentials.dig(:META_PIXEL_ID)
    @access_token = Rails.application.credentials.dig(:META_ACCESS_TOKEN)
    @api_version = 'v21.0'
    @base_url = "https://graph.facebook.com/#{@api_version}/#{@pixel_id}/events"
  end

  # Check if credentials are configured
  def credentials_configured?
    @pixel_id.present? && @access_token.present?
  end

  # Send Lead event when customer is created or contact is established
  def send_lead_event(customer)
    return unless credentials_configured?
    
    event_data = build_event_data(customer, 'Lead', {
      content_name: 'Lead Generation',
      content_category: customer.lead_source || 'Unknown',
      custom_data: {
        lead_source: customer.lead_source,
        customer_type: customer.customer_type,
        project_type: customer.project_type,
        platform: customer.platform,
        country: customer.country
      }
    })

    send_event(event_data, customer, 'Lead')
  end

  # Send ViewContent event when customer details are viewed/analyzed
  def send_view_content_event(customer)
    return unless credentials_configured?
    
    event_data = build_event_data(customer, 'ViewContent', {
      content_name: "Customer Profile: #{customer.name}",
      content_category: customer.lead_source || 'Customer Management',
      custom_data: {
        customer_status: customer.status,
        has_phone: customer.phone.present?,
        has_email: customer.email.present?,
        timezone: customer.timezone
      }
    })

    send_event(event_data, customer, 'ViewContent')
  end

  # Send InitiateCheckout event when proposal is sent
  def send_initiate_checkout_event(customer, deal = nil)
    return unless credentials_configured?
    
    custom_data = {
      customer_status: customer.status,
      proposal_stage: 'sent'
    }
    
    if deal
      custom_data.merge!({
        deal_amount: deal.amount,
        deal_title: deal.title,
        deal_stage: deal.deal_stage&.name
      })
    end

    event_data = build_event_data(customer, 'InitiateCheckout', {
      content_name: 'Proposal Sent',
      content_category: 'Sales Process',
      value: deal&.amount,
      currency: 'USD',
      custom_data: custom_data
    })

    send_event(event_data, customer, 'InitiateCheckout')
  end

  # Send Purchase event when customer converts or deal is won
  def send_purchase_event(customer, deal = nil)
    return unless credentials_configured?
    
    value = deal&.amount || customer.project_estimated_cost || 0
    
    custom_data = {
      customer_status: customer.status,
      conversion_type: deal ? 'deal_won' : 'customer_converted',
      project_type: customer.project_type,
      platform: customer.platform,
      project_scope: customer.project_scope
    }
    
    if deal
      custom_data.merge!({
        deal_id: deal.id,
        deal_title: deal.title,
        deal_stage: deal.deal_stage&.name,
        closing_date: deal.closing_date&.iso8601
      })
    end

    event_data = build_event_data(customer, 'Purchase', {
      content_name: deal ? "Deal Won: #{deal.title}" : 'Customer Converted',
      content_category: 'Revenue',
      value: value,
      currency: 'USD',
      custom_data: custom_data
    })

    send_event(event_data, customer, 'Purchase')
  end

  # Send CompleteRegistration event when customer details are completed
  def send_complete_registration_event(customer)
    return unless credentials_configured?
    
    event_data = build_event_data(customer, 'CompleteRegistration', {
      content_name: 'Customer Registration Complete',
      content_category: 'Customer Onboarding',
      custom_data: {
        has_phone: customer.phone.present?,
        has_email: customer.email.present?,
        has_company: customer.company.present?,
        lead_source: customer.lead_source,
        registration_completeness: calculate_registration_completeness(customer)
      }
    })

    send_event(event_data, customer, 'CompleteRegistration')
  end

  # Send Contact event when customer communication status changes
  def send_contact_event(customer, communication_type)
    return unless credentials_configured?
    
    event_data = build_event_data(customer, 'Contact', {
      content_name: "Contact via #{communication_type}",
      content_category: 'Customer Communication',
      custom_data: {
        communication_type: communication_type,
        customer_status: customer.status,
        call_status: customer.call_status,
        email_status: customer.email_status,
        whatsapp_status: customer.whatsapp_status,
        linkedin_status: customer.linkedin_status
      }
    })

    send_event(event_data, customer, 'Contact')
  end


  private

  def build_event_data(customer, event_name, additional_data = {})
    # Generate event_id for deduplication
    event_id = generate_event_id(customer, event_name)
    
    # Build comprehensive user data for maximum matching
    user_data = build_user_data(customer)
    
    # Build custom data
    custom_data = {
      customer_id: customer.id,
      customer_name: customer.name,
      lead_source: customer.lead_source,
      customer_type: customer.customer_type,
      created_at: customer.created_at.iso8601,
      user_assigned: customer.user&.name
    }.merge(additional_data[:custom_data] || {})

    # Main event data structure
    event_data = {
      event_name: event_name,
      event_time: Time.current.to_i,
      event_id: event_id,
      action_source: 'system_generated',
      user_data: user_data,
      custom_data: custom_data.compact
    }

    # Add additional data (value, currency, content_name, etc.)
    additional_data.except(:custom_data).each do |key, value|
      next if value.nil?
      event_data[:custom_data][key.to_s] = value
    end

    event_data
  end

  def build_user_data(customer)
    user_data = {}

    # Email (hashed if present)
    if customer.email.present?
      user_data[:em] = [hash_data(customer.email.downcase.strip)]
    end

    # Phone (hashed if present)
    if customer.phone.present?
      # Remove all non-digit characters except +
      clean_phone = customer.phone.gsub(/[^\d+]/, '')
      user_data[:ph] = [hash_data(clean_phone)]
    end

    # First and Last name (if we can extract from full name)
    if customer.name.present?
      name_parts = customer.name.split(' ')
      if name_parts.length >= 2
        user_data[:fn] = [hash_data(name_parts.first.downcase.strip)]
        user_data[:ln] = [hash_data(name_parts.last.downcase.strip)]
      else
        user_data[:fn] = [hash_data(customer.name.downcase.strip)]
      end
    end

    # Company name
    if customer.company.present?
      user_data[:external_id] = [hash_data("company_#{customer.company.downcase.strip}")]
    end

    # Country (if available)
    if customer.country.present?
      user_data[:country] = [hash_data(customer.country.downcase.strip)]
    end

    # Meta-specific tracking parameters
    if customer.facebook_click_id.present?
      user_data[:fbc] = customer.facebook_click_id
    end

    if customer.browser_id.present?
      user_data[:fbp] = customer.browser_id
    end

    # Meta Lead ID (most important for lead ads)
    if customer.meta_lead_id.present?
      user_data[:lead_id] = customer.meta_lead_id
    end

    # Add client IP and user agent if available (could be enhanced later)
    # user_data[:client_ip_address] = request_ip if request_ip.present?
    # user_data[:client_user_agent] = user_agent if user_agent.present?

    user_data.compact
  end

  def hash_data(data)
    Digest::SHA256.hexdigest(data.to_s)
  end

  def generate_event_id(customer, event_name)
    # Create unique event ID for deduplication
    base_string = "#{customer.id}_#{event_name}_#{Time.current.to_date}"
    Digest::SHA256.hexdigest(base_string)[0, 32]
  end

  def calculate_registration_completeness(customer)
    fields = [:name, :email, :phone, :company, :country, :project_type]
    completed_fields = fields.count { |field| customer.send(field).present? }
    (completed_fields.to_f / fields.length * 100).round
  end

  def send_event(event_data, customer, event_name)
    uri = URI.parse(@base_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    
    payload = {
      data: [event_data],
      access_token: @access_token,
      partner_agent: 'tecaudex_crm_v1.0'
    }

    request.body = JSON.generate(payload)

    begin
      response = http.request(request)
      parsed_response = JSON.parse(response.body)

      if response.code.to_i == 200 && parsed_response['events_received']
        Rails.logger.info("Meta Conversions API: Successfully sent #{event_name} event for customer #{customer.id}")
        update_customer_meta_tracking(customer, event_name, event_data)
        { success: true, response: parsed_response }
      else
        error_message = parsed_response['error']&.dig('message') || 'Unknown error'
        Rails.logger.error("Meta Conversions API Error for customer #{customer.id}: #{error_message}")
        { success: false, error: error_message, response: parsed_response }
      end
    rescue StandardError => e
      Rails.logger.error("Meta Conversions API Exception for customer #{customer.id}: #{e.message}")
      { success: false, error: e.message }
    end
  end

  def update_customer_meta_tracking(customer, event_name, event_data)
    # Parse existing events or initialize empty array
    existing_events = customer.meta_events_sent.present? ? JSON.parse(customer.meta_events_sent) : []
    
    # Add new event
    existing_events << {
      event_name: event_name,
      event_id: event_data[:event_id],
      sent_at: Time.current.iso8601
    }

    # Keep only last 50 events to prevent bloat
    existing_events = existing_events.last(50)

    # Update customer
    customer.update_columns(
      meta_events_sent: existing_events.to_json,
      last_meta_event_sent_at: Time.current
    )
  end

end