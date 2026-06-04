# Wraps Twilio Lookup v2 (line_type_intelligence) to determine whether a
# customer's phone number is reachable on WhatsApp. We don't have a direct
# "is on WhatsApp?" API, but the combination of line type + carrier is a strong
# proxy: disposable/burner VoIP carriers (Pinger, TextNow, etc.) are
# essentially never registered on WhatsApp.
class PhoneLookupService
  # Carriers whose subscribers are virtually never on WhatsApp. Sub-string
  # match because Twilio returns concatenated names like
  # "Pinger - Bandwidth.com - Sinch".
  DISPOSABLE_CARRIERS = %w[
    Pinger TextNow TextFree Hushed TextMe Sideline Sinch Burner Talkatone
  ].freeze

  # line_types that almost always mean "won't reach a real WhatsApp account":
  # nonFixedVoip = unattended VoIP / burner.
  UNREACHABLE_LINE_TYPES = %w[nonFixedVoip].freeze

  CACHE_TTL = 30.days

  def initialize
    sid   = Rails.application.credentials.dig(:TWILIO_ACCOUNT_SID)
    token = Rails.application.credentials.dig(:TWILIO_AUTH_TOKEN)
    raise 'Twilio credentials not configured' unless sid && token
    @client = Twilio::REST::Client.new(sid, token)
  end

  # Calls Twilio Lookup for `phone` and writes the result onto the customer
  # record. Skips the call if we've checked recently unless `force: true`.
  def check!(customer, force: false)
    return { success: false, error: 'Customer has no phone' } if customer.phone.blank?
    if !force && fresh?(customer)
      return { success: true, cached: true, line_type: customer.phone_line_type, carrier: customer.phone_carrier }
    end

    result = @client.lookups.v2.phone_numbers(customer.phone)
                                .fetch(fields: 'line_type_intelligence')

    customer.update(
      phone_line_type:         result.line_type_intelligence&.dig('type'),
      phone_carrier:           result.line_type_intelligence&.dig('carrier_name'),
      phone_country_code:      result.country_code,
      phone_lookup_checked_at: Time.current
    )

    {
      success:   true,
      cached:    false,
      line_type: customer.phone_line_type,
      carrier:   customer.phone_carrier
    }
  rescue Twilio::REST::RestError => e
    Rails.logger.warn("[PhoneLookup] failed for customer ##{customer.id} (#{customer.phone}): #{e.code} #{e.message}")
    { success: false, error: e.message, code: e.code }
  rescue StandardError => e
    Rails.logger.warn("[PhoneLookup] error for customer ##{customer.id}: #{e.class} #{e.message}")
    { success: false, error: e.message }
  end

  private

  def fresh?(customer)
    customer.phone_lookup_checked_at.present? &&
      customer.phone_lookup_checked_at > CACHE_TTL.ago
  end
end
