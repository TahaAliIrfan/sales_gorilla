require "net/http"
require "uri"
require "json"
require "digest"

# Sends events to Meta's Conversions API. Reads per-organization config from
# OrganizationFeature(:meta_conversions): pixel_id, access_token, optional
# test_event_code (Meta Events Manager test mode), `events_enabled` list, and
# `eligible_sources` list. Every send is logged to MetaConversionLog.
class MetaConversionsApiService
  attr_reader :pixel_id, :access_token, :test_event_code, :events_enabled, :eligible_sources,
              :customer_status_mappings, :deal_stage_mappings, :source_action_sources

  def initialize(organization: nil)
    @organization = organization || ActsAsTenant.current_tenant
    @settings = @organization&.feature(:meta_conversions)&.settings_hash || {}

    @pixel_id        = @settings["pixel_id"]
    @access_token    = @settings["access_token"]
    @test_event_code = @settings["test_event_code"].presence
    @events_enabled  = Array(@settings["events_enabled"]).presence ||
                       OrganizationFeature::META_DEFAULT_EVENTS
    @eligible_sources = Array(@settings["eligible_sources"]).presence ||
                        OrganizationFeature::META_DEFAULT_ELIGIBLE_SOURCES

    @customer_status_mappings = (@settings["customer_status_mappings"] || {}).presence ||
                                OrganizationFeature::META_DEFAULT_CUSTOMER_STATUS_MAPPINGS
    @deal_stage_mappings      = @settings["deal_stage_mappings"] || {}
    @source_action_sources    = (@settings["source_action_sources"] || {}).presence ||
                                OrganizationFeature::META_DEFAULT_SOURCE_ACTION_SOURCES
  end

  def feature_enabled?
    @organization&.feature_enabled?(:meta_conversions) || false
  end

  def credentials_configured?
    feature_enabled? && @pixel_id.present? && @access_token.present?
  end

  def event_enabled?(event_name)
    @events_enabled.include?(event_name.to_s)
  end

  def source_eligible?(lead_source)
    return false if lead_source.blank?
    @eligible_sources.include?(lead_source)
  end

  # Returns the Meta event name configured for a Customer status, or nil if
  # the admin hasn't mapped this status to anything.
  def event_for_customer_status(status)
    return nil if status.blank?
    @customer_status_mappings[status.to_s].presence
  end

  # Returns the Meta event name configured for a DealStage. Keys are stage IDs
  # stored as strings in the settings hash (JSON serialization).
  def event_for_deal_stage(deal_stage_id)
    return nil if deal_stage_id.blank?
    @deal_stage_mappings[deal_stage_id.to_s].presence
  end

  # The Meta action_source value to use for events from this lead source. Defaults
  # to "system_generated" if the source isn't configured (matches Meta's catch-all
  # for backend events).
  def action_source_for(lead_source)
    config = @source_action_sources[lead_source.to_s] || {}
    (config["action_source"].presence || "system_generated").to_s
  end

  # True when this source's CAPI events should only fire if `meta_lead_id` is
  # present (i.e. came through Meta Lead Ads webhook). Defaults to false so
  # non-Lead-Ads sources don't get unnecessarily blocked.
  def requires_lead_id?(lead_source)
    !!(@source_action_sources[lead_source.to_s] || {})["require_lead_id"]
  end

  # Inspects a customer (or hash-like with the relevant attributes) and reports
  # which identifiers are available for Meta matching. Used by the Features UI
  # to give admins a "match quality" preview per lead source.
  #
  # Quality bands roughly match Meta's documented thresholds:
  #   - "Great": lead_id OR (email AND phone) AND fbp OR fbc
  #   - "Good":  any 2 of [lead_id, email, phone, fbc, fbp]
  #   - "Poor":  fewer than 2 identifiers
  def match_quality_summary(sample_customer: nil)
    identifiers = identifier_presence(sample_customer)
    count = identifiers.values.count(true)
    quality =
      if identifiers[:lead_id] || (identifiers[:email] && identifiers[:phone] && (identifiers[:fbp] || identifiers[:fbc]))
        "Great"
      elsif count >= 2
        "Good"
      else
        "Poor"
      end

    { identifiers: identifiers, count: count, quality: quality }
  end

  # Standard pathway used by Customer/Deal callbacks. Returns the result hash.
  def send_form_lead_event(customer, event_name, amount = nil, action_source = "system_generated", options = {})
    payload = build_payload([ form_lead_event(customer, event_name, amount, action_source, options) ])
    result  = post(payload)
    log_result(customer, event_name, payload, result)
    result
  end

  # Synthetic test event used by the Settings > Features > Meta "Send test"
  # button. Doesn't write a MetaConversionLog (no real customer involved).
  def send_test_event
    return { success: false, error: "Meta credentials are not configured" } unless credentials_configured?

    event = {
      event_name: "Lead",
      event_time: Time.now.to_i,
      action_source: "system_generated",
      user_data: {
        em: sha256("test@example.com"),
        ph: sha256("1234567890"),
        fn: sha256("Test"),
        ln: sha256("User")
      },
      custom_data: {
        lead_event_source: "CRM",
        event_source: "crm",
        test_send_from: "Settings > Features"
      }
    }

    post(build_payload([ event ]))
  end

  private

  # Boolean presence map for Meta user_data identifiers. Used by the match
  # quality preview. If a customer is supplied, checks the real record;
  # otherwise treats every identifier as theoretically available so the UI
  # can preview what _could_ be sent for a source.
  def identifier_presence(customer)
    if customer
      {
        lead_id: customer.meta_lead_id.present?,
        email:   customer.email.present?,
        phone:   customer.phone.present?,
        name:    customer.name.present?,
        fbc:     (customer.facebook_click_id.presence || customer.try(:fbclid)).present?,
        fbp:     customer.browser_id.present?
      }
    else
      { lead_id: true, email: true, phone: true, name: true, fbc: true, fbp: true }
    end
  end

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
    payload = { data: events }
    payload[:test_event_code] = @test_event_code if @test_event_code.present?
    payload
  end

  # Assembles user_data hash; only includes keys that have a value on the record.
  # All PII must be SHA256 hashed before sending (except lead_id, fbc, fbp).
  def user_data_for(customer)
    data = {}

    data[:em]      = sha256(customer.email.downcase.strip) if customer.email.present?
    data[:ph]      = sha256(normalize_phone(customer.phone)) if customer.phone.present?
    data[:lead_id] = customer.meta_lead_id.to_i             if customer.meta_lead_id.present?

    first_name, last_name = split_name(customer.name)
    data[:fn] = sha256(first_name) if first_name.present?
    data[:ln] = sha256(last_name)  if last_name.present?

    country = customer.country_code.presence || customer.country.presence
    data[:country] = sha256(country.downcase.strip) if country.present?
    data[:ct]      = sha256(customer.city.downcase.strip)  if customer.city.present?
    data[:st]      = sha256(customer.state.downcase.strip) if customer.state.present?

    fbc_value = customer.facebook_click_id.presence || customer.fbclid.presence
    data[:fbc] = fbc_value if fbc_value.present?
    data[:fbp] = customer.browser_id if customer.browser_id.present?

    data
  end

  def split_name(full_name)
    return [ nil, nil ] if full_name.blank?
    parts = full_name.strip.split(" ", 2)
    [ parts[0], parts[1] ]
  end

  def normalize_phone(phone)
    phone.to_s.gsub(/\D/, "")
  end

  def sha256(value)
    Digest::SHA256.hexdigest(value.to_s)
  end

  def graph_url
    "https://graph.facebook.com/v25.0/#{@pixel_id}/events?access_token=#{@access_token}"
  end

  def post(payload)
    uri = URI.parse(graph_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
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
