class TwilioService
  def initialize
    @account_sid = Rails.application.credentials.dig(:TWILIO_ACCOUNT_SID)
    @auth_token = Rails.application.credentials.dig(:TWILIO_AUTH_TOKEN)
    @api_key = Rails.application.credentials.dig(:TWILIO_API_KEY)
    @api_secret = Rails.application.credentials.dig(:TWILIO_API_SECRET)
    @application_sid = Rails.application.credentials.dig(:TWILIO_APP_SID)
    @default_caller_id = "+447897021964"

    # Verify credentials are present
    unless @account_sid && @auth_token && @application_sid
      Rails.logger.error("Missing required phone service credentials")
      raise "Phone service credentials not properly configured"
    end

    @client = Twilio::REST::Client.new(@account_sid, @auth_token)
    @app_url = "https://crm.tecaudex.com"

    # if Rails.env.development?
    #   @app_url = 'https://6547-185-141-119-111.ngrok-free.app'
    # else
    #   @app_url = 'https://crm.tecaudex.com'
    # end
  end

  def generate_capability_token(identity = "web_user")
    begin
      # Use API Key/Secret if available, otherwise fall back to Account SID/Auth Token
      api_key = @api_key.presence || @account_sid
      api_secret = @api_secret.presence || @auth_token

      # Create Access Token with identity and TTL
      token = Twilio::JWT::AccessToken.new(
        @account_sid,
        api_key,
        api_secret,
        identity: identity,
        ttl: 3600 # 1 hour
      )

      # Create and add Voice Grant
      voice_grant = Twilio::JWT::AccessToken::VoiceGrant.new
      voice_grant.outgoing_application_sid = @application_sid
      voice_grant.incoming_allow = true

      token.add_grant(voice_grant)

      token.to_jwt
    rescue => e
      Rails.logger.error("Error generating access token: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise "Unable to initialize phone service. Please try again later."
    end
  end

  def generate_voice_response(phone_number, caller_id = nil, customer_id, user_id)
    # Validate and use verified caller ID
    verified_caller_id = get_verified_caller_id(caller_id)

    Rails.logger.info("Voice TwiML - To: #{phone_number}, CallerId: #{verified_caller_id}, CustomerId: #{customer_id}, UserId: #{user_id}")

    Twilio::TwiML::VoiceResponse.new do |r|
      if phone_number
        # Handle client-to-client calls
        if phone_number.start_with?("client:")
          r.dial(
            caller_id: verified_caller_id,
            timeout: 30,
            record: "record-from-answer",
            trim: "trim-silence",
            recording_status_callback: "#{@app_url}/calling/recording_status?customer_id=#{customer_id}&user_id=#{user_id}",
            recording_status_callback_method: "POST"
          ) do |d|
            d.client(phone_number.gsub("client:", ""))
          end
        else
          # Client-to-PSTN call (regular phone number)
          r.dial(
            caller_id: verified_caller_id,
            timeout: 30,
            record: "record-from-answer",
            recording_status_callback: "#{@app_url}/calling/recording_status?customer_id=#{customer_id}&user_id=#{user_id}",
            recording_status_callback_method: "POST"
          ) do |d|
            d.number(phone_number)
          end
        end
      else
        r.say("Welcome. Please specify a phone number to call.")
      end
    end
  rescue => e
    Rails.logger.error("Error generating voice response: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    # Return a basic response if we encounter an error
    Twilio::TwiML::VoiceResponse.new do |r|
      r.say("An error occurred while processing your call.")
    end
  end

  # Get a verified caller ID from available Twilio numbers
  def get_verified_caller_id(requested_caller_id = nil)
    # If a specific caller ID is requested and it's in our verified list, use it
    if requested_caller_id.present?
      available_numbers = fetch_available_numbers
      if available_numbers.any? { |n| n[:phone_number] == requested_caller_id }
        return requested_caller_id
      end

      Rails.logger.warn("Requested caller_id #{requested_caller_id} not found in verified numbers, using default")
    end

    # Fallback to default caller ID
    @default_caller_id
  end

  def call_sales_rep(caller, phone_number, user_id, customer_id = nil)
    Twilio::TwiML::VoiceResponse.new do |r|
      if phone_number
        r.dial(
          caller_id: caller,
          timeout: 30,
          record: "record-from-answer",
          recording_status_callback: "#{@app_url}/calling/recording_status?user_id=#{user_id}&customer_id=#{customer_id}",
          recording_status_callback_method: "POST"
        ) do |d|
          d.number(phone_number)
        end
      else
        r.say("Thanks for calling. We will reach out to you shortly.")
      end
    end
  rescue => e
    Rails.logger.error("Error generating response for inbound call: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    # Return a basic response if we encounter an error
    Twilio::TwiML::VoiceResponse.new do |r|
      r.say("An error occurred while processing your call.")
    end
  end

  def fetch_recordings(limit = 20)
    recordings_data = @client.recordings.list(limit: limit).map do |recording|
      twilio_data = {
        sid: recording.sid,
        duration: recording.duration,
        date: recording.date_created,
        url: "#{@app_url}/calling/play_recording/#{recording.sid}",
        call_sid: recording.call_sid
      }

      twilio_data
    end

    recordings_data
  rescue Twilio::REST::RestError => e
    Rails.logger.error "Error fetching recordings: #{e.message}"
    []
  end

  def fetch_recording_metadata(recording_sid)
    recording = @client.recordings(recording_sid).fetch

    {
      sid: recording.sid,
      duration: recording.duration,
      date: recording.date_created,
      url: "#{@app_url}/calling/play_recording/#{recording.sid}",
      call_sid: recording.call_sid,
      media_url: recording.media_url.to_s
    }
  rescue Twilio::REST::RestError => e
    Rails.logger.error "Error fetching recording metadata #{recording_sid}: #{e.message}"
    raise e
  end

  def fetch_recording(recording_sid)
    recording = @client.recordings(recording_sid).fetch

    # Get the media URL with .mp3 extension for better browser compatibility
    media_url = recording.media_url.to_s
    media_url += ".mp3" unless media_url.end_with?(".mp3")

    {
      media_url: media_url,
      content_type: "audio/mpeg",
      auth: {
        username: @account_sid,
        password: @auth_token
      }
    }
  rescue Twilio::REST::RestError => e
    Rails.logger.error "Error fetching recording #{recording_sid}: #{e.message}"
    raise e
  end

  ALLOWED_US_NUMBER = "+16562700320"

  def fetch_available_numbers
    begin
      incoming_numbers = @client.incoming_phone_numbers.list

      numbers = incoming_numbers.filter_map do |number|
        phone = number.phone_number
        next if phone.start_with?("+1") && phone != ALLOWED_US_NUMBER
        { phone_number: phone, friendly_name: phone }
      end

      return numbers unless numbers.empty?

      [ { phone_number: @default_caller_id, friendly_name: "UK Number" } ]
    rescue => e
      Rails.logger.error("Error fetching available phone numbers: #{e.message}")
      [ { phone_number: @default_caller_id, friendly_name: "UK Number" } ]
    end
  end
end
