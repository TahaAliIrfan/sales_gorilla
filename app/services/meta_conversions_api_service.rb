require 'net/http'
require 'uri'
require 'json'
require 'digest'

class MetaConversionsApiService
  attr_reader :pixel_id, :access_token

  def initialize
    @pixel_id = Rails.application.credentials.dig(:META_PIXEL_ID) || ENV['META_PIXEL_ID']
    @access_token = Rails.application.credentials.dig(:META_ACCESS_TOKEN) || ENV['META_ACCESS_TOKEN']
    @api_version = 'v22.0'
    @base_url = "https://graph.facebook.com/123/123/events"
  end

  def credentials_configured?
    @pixel_id.present? && @access_token.present?
  end

  # Send Lead event when customer is created from Meta traffic
  def send_lead_event(customer)
    return unless credentials_configured?

    event_data = build_event_data(customer, 'Lead', {
      content_name: 'Lead Generation',
      content_category: customer.lead_source || 'Inbound',
      custom_data: {
        lead_source: customer.lead_source,
        utm_source: customer.utm_source,
        utm_campaign: customer.utm_campaign,
        project_type: customer.project_type,
        country: customer.country
      }
    })

    send_event(event_data, customer, 'Lead')
  end

  # Send CompleteRegistration event when contact is established
  def send_complete_registration_event(customer)
    return unless credentials_configured?

    event_data = build_event_data(customer, 'CompleteRegistration', {
      content_name: 'Contact Established',
      content_category: 'Sales Process',
      custom_data: {
        has_phone: customer.phone.present?,
        has_email: customer.email.present?,
        lead_source: customer.lead_source
      }
    })

    send_event(event_data, customer, 'CompleteRegistration')
  end

  # Send InitiateCheckout event when proposal is sent
  def send_initiate_checkout_event(customer, deal = nil)
    return unless credentials_configured?

    custom_data = { customer_status: customer.status, proposal_stage: 'sent' }
    if deal
      custom_data.merge!(deal_amount: deal.amount, deal_title: deal.title)
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

  # Send Purchase event when customer converts
  def send_purchase_event(customer, deal = nil)
    return unless credentials_configured?

    value = deal&.amount || customer.project_estimated_cost || 0

    custom_data = {
      customer_status: customer.status,
      project_type: customer.project_type,
      project_scope: customer.project_scope
    }
    if deal
      custom_data.merge!(deal_id: deal.id, deal_title: deal.title)
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

  # Send Contact event when communication status changes
  def send_contact_event(customer, communication_type)
    return unless credentials_configured?

    event_data = build_event_data(customer, 'Contact', {
      content_name: "Contact via #{communication_type}",
      content_category: 'Customer Communication',
      custom_data: {
        communication_type: communication_type,
        customer_status: customer.status
      }
    })

    send_event(event_data, customer, 'Contact')
  end

  # Send ViewContent (unused but available)
  def send_view_content_event(customer)
  end

  private

  def build_event_data(customer, event_name, additional_data = {})
    event_id = generate_event_id(customer, event_name)
    user_data = build_user_data(customer)

    custom_data = {
      customer_id: customer.id,
      lead_source: customer.lead_source,
      utm_source: customer.utm_source,
      utm_campaign: customer.utm_campaign
    }.merge(additional_data[:custom_data] || {}).compact

    event_data = {
      event_name: event_name,
      event_time: Time.current.to_i,
      event_id: event_id,
      action_source: 'website',
      user_data: user_data,
      custom_data: custom_data
    }

    # Add value/currency at top level if present
    event_data[:custom_data][:value] = additional_data[:value] if additional_data[:value].present?
    event_data[:custom_data][:currency] = additional_data[:currency] if additional_data[:currency].present?

    event_data
  end

  def build_user_data(customer)
    user_data = {}

    if customer.email.present?
      user_data[:em] = [hash_data(customer.email.downcase.strip)]
    end

    if customer.phone.present?
      clean_phone = customer.phone.gsub(/[^\d]/, '')
      user_data[:ph] = [hash_data(clean_phone)]
    end

    if customer.name.present?
      name_parts = customer.name.split(' ')
      if name_parts.length >= 2
        user_data[:fn] = [hash_data(name_parts.first.downcase.strip)]
        user_data[:ln] = [hash_data(name_parts.last.downcase.strip)]
      else
        user_data[:fn] = [hash_data(customer.name.downcase.strip)]
      end
    end

    if customer.country.present?
      user_data[:country] = [hash_data(customer.country.downcase.strip)]
    end

    # Meta click ID (fbc) — from fbclid param, stored in facebook_click_id
    if customer.facebook_click_id.present?
      # fbc format: fb.1.{timestamp}.{fbclid}
      user_data[:fbc] = "fb.1.#{customer.created_at.to_i}.#{customer.facebook_click_id}"
    end

    # Meta browser ID (fbp) — from _fbp cookie, stored in browser_id
    if customer.browser_id.present?
      user_data[:fbp] = customer.browser_id
    end

    # Lead ID for lead ads
    if customer.meta_lead_id.present?
      user_data[:lead_id] = customer.meta_lead_id
    end

    user_data.compact
  end

  def hash_data(data)
    Digest::SHA256.hexdigest(data.to_s)
  end

  def generate_event_id(customer, event_name)
    base_string = "#{customer.id}_#{event_name}_#{Time.current.to_date}"
    Digest::SHA256.hexdigest(base_string)[0, 32]
  end

  def send_event(event_data, customer, event_name)
    uri = URI.parse(@base_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    http.open_timeout = 5

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'

    payload = {
      data: [event_data],
      access_token: @access_token
    }

    request.body = JSON.generate(payload)

    begin
      response = http.request(request)
      parsed_response = JSON.parse(response.body)

      if response.code.to_i == 200 && parsed_response['events_received']
        Rails.logger.info("Meta CAPI: Sent #{event_name} for customer #{customer.id} (events_received: #{parsed_response['events_received']})")
        { success: true, response: parsed_response }
      else
        error_message = parsed_response.dig('error', 'message') || 'Unknown error'
        Rails.logger.error("Meta CAPI error for customer #{customer.id} [#{event_name}]: #{error_message}")
        { success: false, error: error_message }
      end
    rescue StandardError => e
      Rails.logger.error("Meta CAPI exception for customer #{customer.id} [#{event_name}]: #{e.message}")
      { success: false, error: e.message }
    end
  end
end
