class CallingController < ApplicationController
  # Skip CSRF protection for Twilio webhooks
  skip_before_action :verify_authenticity_token, only: [:voice, :recording_status]
  layout 'dashboard'

  # Display the browser-based phone interface
  def index
    @twilio_numbers = twilio_service.fetch_available_numbers
    @deals = Deal.includes(:customer).order(created_at: :desc)

    if params[:deal_id].present?
      @selected_deal = Deal.find_by(id: params[:deal_id])
      @phone_to_call = @selected_deal&.customer&.phone
    elsif params[:phone].present?
      @phone_to_call = params[:phone]
    end

    @auto_dial = @phone_to_call.present?
  end

  # Generate a Twilio Client capability token
  def token
    token = twilio_service.generate_capability_token
    render json: { token: token }
  end

  # Handle outgoing calls
  def voice
    phone_number = params[:To]
    caller_id = params[:caller_id]
    deal_id = params[:deal_id]

    # Log the call if a deal is associated
    if deal_id.present?
      deal = Deal.find_by(id: deal_id)
      if deal
        deal.deal_activities.create(
          action: 'call',
          details: "Call made to #{phone_number}",
          user: current_user
        )
      end
    end

    if params[:controller] == 'calling' && params[:deal_id].present?
      response = twilio_service.generate_voice_response(phone_number, caller_id)
      render xml: response.to_s
    else
      response = twilio_service.call_sales_rep('+923237399596')
      render xml: response.to_s
    end
  end

  # Handle recording status callbacks from Twilio
  def recording_status
    recording_sid = params[:RecordingSid]
    call_sid = params[:CallSid]
    duration = params[:RecordingDuration].to_i
    url = params[:RecordingUrl]
    
    # Find the deal associated with this call
    deal_id = session[:current_call_deal_id]
    
    if deal_id.present?
      deal = Deal.find_by(id: deal_id)
      if deal && deal.customer.present?
        # Create a recording record
        recording = Recording.create(
          sid: recording_sid,
          call_sid: call_sid,
          duration: duration,
          url: url,
          date: Time.current,
          user: current_user,
          customer: deal.customer
        )
        
        # Log the recording in deal activities
        deal.deal_activities.create(
          action: 'recording',
          details: "Call recording saved (#{duration} seconds)",
          user: current_user
        )
      end
    end
    
    head :ok
  end

  # Fetch list of recordings
  def recordings
    if params[:customer_id].present?
      # Get recordings for a specific customer
      customer = Customer.find_by(id: params[:customer_id])
      recordings = customer ? customer.recordings.recent.limit(20) : []
      render json: recordings_to_json(recordings)
    else
      # Get all recordings from Twilio and match with our database
      twilio_recordings = twilio_service.fetch_recordings
      
      # Convert to JSON format for the frontend
      render json: twilio_recordings
    end
  end

  # Play a specific recording
  def play_recording
    recording_sid = params[:sid]

    begin
      recording = Recording.find_by(sid: recording_sid)
      
      if recording
        # Use the URL stored in our database
        media_url = recording.url
      else
        # Fallback to fetching from Twilio
        twilio_recording = twilio_service.fetch_recording(recording_sid)
        media_url = twilio_recording[:media_url]
      end

      response = HTTParty.get(
        media_url,
        basic_auth: {
          username: Rails.application.credentials.dig(:TWILIO_ACCOUNT_SID),
          password: Rails.application.credentials.dig(:TWILIO_AUTH_TOKEN)
        }
      )

      content_type = response.headers['content-type']
      send_data response.body, type: content_type, disposition: 'inline'
    rescue => e
      Rails.logger.error "Error fetching recording: #{e.message}"
      render plain: "Error fetching recording: #{e.message}", status: :internal_server_error
    end
  end

  # Fetch available Twilio phone numbers
  def available_numbers
    twilio_numbers = twilio_service.fetch_available_numbers
    render json: twilio_numbers
  end

  # Store the current deal ID in the session
  def store_deal_id
    session[:current_call_deal_id] = params[:deal_id]
    head :ok
  end

  private

  def twilio_service
    @twilio_service ||= TwilioService.new
  end
  
  def recordings_to_json(recordings)
    recordings.map do |recording|
      {
        sid: recording.sid,
        duration: recording.duration,
        date: recording.date,
        url: "#{request.base_url}/calling/play_recording/#{recording.sid}",
        call_sid: recording.call_sid,
        customer_name: recording.customer&.name,
        user_name: recording.user&.name
      }
    end
  end
end 