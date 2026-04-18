require 'net/http'
require 'uri'
require 'json'
require 'digest'

class MetaConversionsApiService
  attr_reader :pixel_id, :access_token

  def initialize
    @pixel_id = Rails.application.credentials.dig(:META_PIXEL_ID)
    @access_token = Rails.application.credentials.dig(:META_ACCESS_TOKEN)

    @base_url = "https://graph.facebook.com/v25.0/#{@pixel_id}/events?access_token=#{@access_token}"
  end

  def credentials_configured?
    @pixel_id.present? && @access_token.present?
  end

  def send_form_lead_event(customer, event_name, amount=nil, action_source='system_generated', options={})
    payload = build_payload([form_lead_event(customer, event_name, amount, action_source, options)])
    result = post(payload)
    log_result(customer, event_name, payload, result)
    result
  end

  private

  def form_lead_event(customer, event_name, amount, action_source, options)
    custom_data = {
      lead_event_source: "CRM",
      event_source: "crm"
    }

    if event_name == "Purchase" && amount.present?
      custom_data[:currency] = "USD"
      custom_data[:value]    = amount
    end

    event = {
      event_name: event_name,
      event_time: Time.now.to_i,
      action_source: action_source,
      user_data: user_data_for(customer),
      custom_data: custom_data,
      original_event_data: {
        event_name: event_name,
        event_time: customer.created_at.to_i
      }
    }

    event[:messaging_channel] = options[:messaging_channel] if options[:messaging_channel].present?

    event
  end

  def build_payload(events)
    { data: events }
  end

  # Assembles user_data hash; only includes keys that have a value on the record.
  # All PII must be SHA256 hashed before sending (except lead_id, fbc, fbp).
  def user_data_for(customer)
    data = {}

    # --- contact ---
    data[:em]      = sha256(customer.email.downcase.strip) if customer.email.present?
    data[:ph]      = sha256(normalize_phone(customer.phone)) if customer.phone.present?
    data[:lead_id] = customer.meta_lead_id.to_i             if customer.meta_lead_id.present?

    # --- name ---
    first_name, last_name = split_name(customer.name)
    data[:fn] = sha256(first_name) if first_name.present?
    data[:ln] = sha256(last_name)  if last_name.present?

    # --- location ---
    # Meta expects lowercase ISO 3166-1 alpha-2 country code (e.g. "us")
    country = customer.country_code.presence || customer.country.presence
    data[:country] = sha256(country.downcase.strip) if country.present?
    data[:ct]      = sha256(customer.city.downcase.strip)  if customer.city.present?
    data[:st]      = sha256(customer.state.downcase.strip) if customer.state.present?

    # --- Meta click / browser tracking (not hashed) ---
    fbc_value = customer.facebook_click_id.presence || customer.fbclid.presence
    data[:fbc] = fbc_value if fbc_value.present?
    data[:fbp] = customer.browser_id if customer.browser_id.present?

    data
  end

  # Returns [first_name, last_name] from a full name string
  def split_name(full_name)
    return [nil, nil] if full_name.blank?

    parts = full_name.strip.split(' ', 2)
    [parts[0], parts[1]]
  end

  # E.164 phone numbers from the DB include a leading "+"; Meta expects digits only
  def normalize_phone(phone)
    phone.to_s.gsub(/\D/, '')
  end

  def sha256(value)
    Digest::SHA256.hexdigest(value.to_s)
  end

  def post(payload)
    uri = URI.parse(@base_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)

    handle_response(response)
  rescue StandardError => e
    Rails.logger.error("[MetaConversionsAPI] Request failed: #{e.message}")
    { success: false, error: e.message }
  end

  def handle_response(response)
    body = JSON.parse(response.body) rescue response.body

    if response.is_a?(Net::HTTPSuccess)
      Rails.logger.info("[MetaConversionsAPI] Event sent successfully: #{body}")
      { success: true, body: body }
    else
      Rails.logger.error("[MetaConversionsAPI] Error #{response.code}: #{body}")
      { success: false, code: response.code, body: body }
    end
  end

  def log_result(customer, event_name, payload, result)
    customer.meta_conversion_logs.create!(
      event_name: event_name,
      request_payload: payload,
      success: result[:success],
      response_code: result[:code],
      response_body: result[:body],
      error_message: result[:error]
    )
  rescue => e
    Rails.logger.error("[MetaConversionsAPI] Failed to save log: #{e.message}")
  end
end
