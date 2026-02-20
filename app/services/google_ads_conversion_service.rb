class GoogleAdsConversionService
  CONVERSION_ACTION_GOOD_LEAD = 'Qualified Lead'
  CONVERSION_ACTION_BAD_LEAD = 'Disqualified Lead'
  DEFAULT_CONVERSION_VALUE_GOOD = 500
  DEFAULT_CONVERSION_VALUE_BAD = 0

  def initialize(customer)
    @customer = customer
  end

  def upload_offline_conversion
    return failure_result("No click ID present") unless click_id.present?
    return failure_result("No lead quality set") unless @customer.lead_quality.present?

    begin
      result = send_conversion_to_google_ads
      
      if result[:success]
        @customer.update!(
          google_conversion_status: 'sent',
          google_conversion_sent_at: Time.current
        )
        Rails.logger.info("Successfully uploaded offline conversion for customer #{@customer.id}")
      else
        @customer.update!(google_conversion_status: 'failed')
        Rails.logger.error("Failed to upload offline conversion for customer #{@customer.id}: #{result[:error]}")
      end

      result
    rescue => e
      @customer.update!(google_conversion_status: 'failed')
      Rails.logger.error("Exception uploading offline conversion for customer #{@customer.id}: #{e.message}")
      failure_result(e.message)
    end
  end

  private

  def click_id
    @customer.gclid.presence || @customer.gbraid.presence || @customer.wbraid.presence
  end

  def click_id_type
    return 'gclid' if @customer.gclid.present?
    return 'gbraid' if @customer.gbraid.present?
    return 'wbraid' if @customer.wbraid.present?
    nil
  end

  def conversion_action_name
    @customer.lead_quality == 'good' ? CONVERSION_ACTION_GOOD_LEAD : CONVERSION_ACTION_BAD_LEAD
  end

  def conversion_value
    @customer.lead_quality == 'good' ? DEFAULT_CONVERSION_VALUE_GOOD : DEFAULT_CONVERSION_VALUE_BAD
  end

  def send_conversion_to_google_ads
    credentials = google_ads_credentials
    
    unless credentials[:configured]
      Rails.logger.warn("Google Ads API not configured. Marking conversion as pending for customer #{@customer.id}")
      @customer.update!(google_conversion_status: 'pending')
      return { success: true, status: 'pending', message: 'Google Ads API not configured - conversion queued' }
    end

    # Build the conversion data
    conversion_data = build_conversion_data

    # Make the API call using Google Ads API
    response = upload_click_conversion(credentials, conversion_data)
    
    if response[:success]
      { success: true, status: 'sent', response: response[:data] }
    else
      failure_result(response[:error])
    end
  end

  def build_conversion_data
    {
      customer_id: google_ads_credentials[:customer_id],
      conversion_action: conversion_action_resource_name,
      click_id_type => click_id,
      conversion_date_time: format_conversion_time(@customer.lead_quality_marked_at),
      conversion_value: conversion_value,
      currency_code: 'USD'
    }
  end

  def conversion_action_resource_name
    customer_id = google_ads_credentials[:customer_id]
    action_id = @customer.lead_quality == 'good' ? 
      google_ads_credentials[:conversion_action_id_good] : 
      google_ads_credentials[:conversion_action_id_bad]
    
    "customers/#{customer_id}/conversionActions/#{action_id}"
  end

  def format_conversion_time(time)
    time.strftime('%Y-%m-%d %H:%M:%S%z')
  end

  def upload_click_conversion(credentials, conversion_data)
    require 'net/http'
    require 'json'

    # Google Ads API endpoint for uploading click conversions
    api_version = 'v15'
    customer_id = credentials[:customer_id].gsub('-', '')
    url = URI("https://googleads.googleapis.com/#{api_version}/customers/#{customer_id}:uploadClickConversions")

    # Get access token
    access_token = get_access_token(credentials)
    return failure_result("Failed to get access token") unless access_token

    # Build request body
    request_body = {
      conversions: [{
        conversionAction: conversion_data[:conversion_action],
        conversionDateTime: conversion_data[:conversion_date_time],
        conversionValue: conversion_data[:conversion_value],
        currencyCode: conversion_data[:currency_code]
      }],
      partialFailure: true
    }

    # Add the appropriate click ID
    case click_id_type
    when 'gclid'
      request_body[:conversions][0][:gclid] = click_id
    when 'gbraid'
      request_body[:conversions][0][:gbraid] = click_id
    when 'wbraid'
      request_body[:conversions][0][:wbraid] = click_id
    end

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(url)
    request['Authorization'] = "Bearer #{access_token}"
    request['Content-Type'] = 'application/json'
    request['developer-token'] = credentials[:developer_token]
    request['login-customer-id'] = credentials[:login_customer_id] if credentials[:login_customer_id].present?
    request.body = request_body.to_json

    response = http.request(request)
    response_body = JSON.parse(response.body) rescue {}

    if response.code.to_i == 200
      { success: true, data: response_body }
    else
      error_message = response_body.dig('error', 'message') || "HTTP #{response.code}"
      { success: false, error: error_message }
    end
  rescue => e
    { success: false, error: e.message }
  end

  def get_access_token(credentials)
    require 'net/http'
    require 'json'

    url = URI('https://oauth2.googleapis.com/token')
    
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    request.body = URI.encode_www_form({
      client_id: credentials[:client_id],
      client_secret: credentials[:client_secret],
      refresh_token: credentials[:refresh_token],
      grant_type: 'refresh_token'
    })

    response = http.request(request)
    response_body = JSON.parse(response.body) rescue {}

    response_body['access_token']
  rescue => e
    Rails.logger.error("Failed to get Google Ads access token: #{e.message}")
    nil
  end

  def google_ads_credentials
    @google_ads_credentials ||= begin
      {
        configured: Rails.application.credentials.dig(:google_ads, :developer_token).present?,
        developer_token: Rails.application.credentials.dig(:google_ads, :developer_token),
        client_id: Rails.application.credentials.dig(:google_ads, :client_id),
        client_secret: Rails.application.credentials.dig(:google_ads, :client_secret),
        refresh_token: Rails.application.credentials.dig(:google_ads, :refresh_token),
        customer_id: Rails.application.credentials.dig(:google_ads, :customer_id),
        login_customer_id: Rails.application.credentials.dig(:google_ads, :login_customer_id),
        conversion_action_id_good: Rails.application.credentials.dig(:google_ads, :conversion_action_id_good),
        conversion_action_id_bad: Rails.application.credentials.dig(:google_ads, :conversion_action_id_bad)
      }
    end
  end

  def failure_result(error)
    { success: false, error: error }
  end
end
