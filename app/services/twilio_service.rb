class TwilioService
  def initialize
    @account_sid = Rails.application.credentials.dig(:TWILIO_ACCOUNT_SID)
    @auth_token = Rails.application.credentials.dig(:TWILIO_AUTH_TOKEN)
    @application_sid = Rails.application.credentials.dig(:TWILIO_APP_SID)
    @default_caller_id = '+447897021964'
    @client = Twilio::REST::Client.new(@account_sid, @auth_token)

    if Rails.env.development?
      @app_url = 'https://6547-185-141-119-111.ngrok-free.app'
    else
      @app_url = 'https://crm.tecaudex.com'
    end
  end

  def generate_capability_token
    capability = Twilio::JWT::ClientCapability.new(
      @account_sid,
      @auth_token
    )
    
    capability.add_scope(
      Twilio::JWT::ClientCapability::OutgoingClientScope.new(@application_sid)
    )

    capability.to_s
  end

  def generate_voice_response(phone_number, caller_id = nil, customer_id, user_id)
    caller_id ||= @default_caller_id
    
    Twilio::TwiML::VoiceResponse.new do |r|
      if phone_number
        r.dial(caller_id: caller_id, 
               record: 'record-from-answer',
               recording_status_callback: "#{@app_url}/calling/recording_status?customer_id=#{customer_id}&user_id=#{user_id}",
               recording_status_callback_method: 'POST') do |d|
          d.number(phone_number)
        end
      else
        r.say('Thanks for calling our team. We will reach out to you shortly.', voice: 'alice')
      end
    end
  end

  def call_sales_rep(caller, phone_number, user_id, customer_id = nil)
    Twilio::TwiML::VoiceResponse.new do |r|
      if phone_number
        r.dial(caller_id: caller,
               record: 'record-from-answer', 
               recording_status_callback: "#{@app_url}/calling/recording_status?user_id=#{user_id}&customer_id=#{customer_id}",
               recording_status_callback_method: 'POST') do |d|
          d.number(phone_number)
        end
      else
        r.say('Thanks for calling our team. We will reach out to you shortly.', voice: 'alice')
      end
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
    
    return recordings_data
  rescue Twilio::REST::RestError => e
    Rails.logger.error "Twilio Error fetching recordings: #{e.message}"
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
    Rails.logger.error "Twilio Error fetching recording metadata #{recording_sid}: #{e.message}"
    raise e
  end

  def fetch_recording(recording_sid)
    recording = @client.recordings(recording_sid).fetch
    
    # Get the media URL with .mp3 extension for better browser compatibility
    media_url = recording.media_url.to_s
    media_url += '.mp3' unless media_url.end_with?('.mp3')
    
    {
      media_url: media_url,
      content_type: 'audio/mpeg',
      auth: {
        username: @account_sid,
        password: @auth_token
      }
    }
  rescue Twilio::REST::RestError => e
    Rails.logger.error "Twilio Error fetching recording #{recording_sid}: #{e.message}"
    raise e
  end

  def fetch_available_numbers
    incoming_numbers = @client.incoming_phone_numbers.list
    
    numbers = incoming_numbers.map do |number|
      {
        phone_number: number.phone_number,
        friendly_name: number.friendly_name
      }
    end
    
    return numbers unless numbers.empty?
    
    [{ phone_number: @default_caller_id, friendly_name: 'Default Number' }]
  end
end 