class GoogleAdsConversionService
  API_VERSION = 'v15'
  CUSTOMER_ID = '2538205658' # Your Google Ads customer ID (without dashes)
  CONVERSION_ACTION_ID = '7505331271' # Your conversion action ID from Google Ads

  def initialize(customer)
    @customer = customer
  end

  def upload_offline_conversion
    return error("No Google click ID") unless click_id.present?
    return error("No lead quality set") unless @customer.lead_quality.present?
    return mark_pending("Google Ads API not configured") unless configured?

    response = send_to_google_ads
    
    if response[:success]
      @customer.update!(google_conversion_status: 'sent', google_conversion_sent_at: Time.current)
      Rails.logger.info("Sent conversion for customer #{@customer.id}")
    else
      @customer.update!(google_conversion_status: 'failed')
      Rails.logger.error("Failed conversion for customer #{@customer.id}: #{response[:error]}")
    end

    response
  rescue => e
    @customer.update!(google_conversion_status: 'failed')
    Rails.logger.error("Error uploading conversion: #{e.message}")
    error(e.message)
  end

  private

  def click_id
    @customer.gclid.presence || @customer.gbraid.presence || @customer.wbraid.presence
  end

  def configured?
    credentials[:developer_token].present?
  end

  def mark_pending(message)
    @customer.update!(google_conversion_status: 'pending')
    { success: true, status: 'pending', message: message }
  end

  def error(message)
    { success: false, error: message }
  end

  def send_to_google_ads
    access_token = fetch_access_token
    return error("Failed to get access token") unless access_token

    uri = URI("https://googleads.googleapis.com/#{API_VERSION}/customers/#{CUSTOMER_ID}:uploadClickConversions")
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['Content-Type'] = 'application/json'
    request['developer-token'] = credentials[:developer_token]
    request.body = conversion_payload.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    body = JSON.parse(response.body) rescue {}

    response.code.to_i == 200 ? { success: true, data: body } : error(body.dig('error', 'message') || "HTTP #{response.code}")
  end

  def conversion_payload
    conversion = {
      conversionAction: "customers/#{CUSTOMER_ID}/conversionActions/#{CONVERSION_ACTION_ID}",
      conversionDateTime: @customer.lead_quality_marked_at.strftime('%Y-%m-%d %H:%M:%S%z'),
      conversionValue: @customer.lead_quality == 'good' ? 500 : 0,
      currencyCode: 'USD'
    }

    # Add the appropriate click ID field
    if @customer.gclid.present?
      conversion[:gclid] = @customer.gclid
    elsif @customer.gbraid.present?
      conversion[:gbraid] = @customer.gbraid
    elsif @customer.wbraid.present?
      conversion[:wbraid] = @customer.wbraid
    end

    { conversions: [conversion], partialFailure: true }
  end

  def fetch_access_token
    uri = URI('https://oauth2.googleapis.com/token')
    
    response = Net::HTTP.post_form(uri, {
      client_id: credentials[:client_id],
      client_secret: credentials[:client_secret],
      refresh_token: credentials[:refresh_token],
      grant_type: 'refresh_token'
    })

    JSON.parse(response.body)['access_token']
  rescue => e
    Rails.logger.error("Failed to get access token: #{e.message}")
    nil
  end

  def credentials
    @credentials ||= {
      developer_token: Rails.application.credentials.dig(:google_ads, :developer_token),
      client_id: Rails.application.credentials.dig(:google_ads, :client_id),
      client_secret: Rails.application.credentials.dig(:google_ads, :client_secret),
      refresh_token: Rails.application.credentials.dig(:google_ads, :refresh_token)
    }
  end
end
