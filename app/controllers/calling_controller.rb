class CallingController < ApplicationController
  # Skip CSRF protection for Twilio webhooks
  skip_before_action :verify_authenticity_token, only: [:voice, :recording_status]
  layout 'dashboard'
  before_action :require_admin, only: [:recordings, :play_recording]

  # Display the browser-based phone interface
  def index
    @twilio_numbers = twilio_service.fetch_available_numbers
    
    # Filter customers by current user unless they're an admin
    if current_user&.admin?
      @customers = Customer.where.not(phone: [nil, ""]).order(created_at: :desc)
    else
      @customers = Customer.where(user_id: current_user&.id).where.not(phone: [nil, ""]).order(created_at: :desc)
    end

    # Add search functionality
    if params[:search].present?
      @customers = @customers.search(params[:search])
    end

    if params[:customer_id].present?
      @selected_customer = Customer.find_by(id: params[:customer_id])
      @phone_to_call = @selected_customer&.phone
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

  def voice
    phone_number = params[:To]
    caller_id = params[:caller_id]

    if params[:controller] == 'calling' && params[:customer_id].present?

      customer = Customer.find_by(id: params[:customer_id])

      if customer.present? && customer.user_id.nil?
        user_id = User.find_by(email: 'sarmad.mansoor@tecaudex.com').id
      else
        user_id = customer.user_id
      end

      response = twilio_service.generate_voice_response(phone_number, caller_id, params[:customer_id], user_id)
      render xml: response.to_s
    else
      customer = Customer.find_by(phone: params[:Called])
      # DEFAULT NUMBER
      user = User.find_by(email: 'sarmad.mansoor@tecaudex.com')
      phone_number = user.phone_number
      user_id = user.id

      # DEFAULT NUMBER END
      #
      if customer.present?
        if customer.user.present?
          phone_number = customer.user.phone_number
          user_id = customer.user_id
        end
      else
        customer = Customer.create(name: 'Unknown Caller', phone: params[:Called])
      end

      response = twilio_service.call_sales_rep(params[:Called], '+923246489818', user_id, customer.id)
      render xml: response.to_s
    end
  end

  # Handle recording status callbacks from Twilio
  def recording_status
    recording_sid = params[:RecordingSid]
    call_sid = params[:CallSid]
    duration = params[:RecordingDuration].to_i
    url = params[:RecordingUrl]

    # Find the customer associated with this call
    customer = Customer.find_by(id: params[:customer_id])
    user = User.find_by(id: params[:user_id])
    if customer.present? && user.present?
      Recording.create(
        sid: recording_sid,
        call_sid: call_sid,
        url: url,
        duration: duration,
        date: Time.current,
        user: user,
        customer: customer
      )

      customer.customer_activities.create(
        action: 'Call Recording',
        details: "Call recording saved (#{duration} seconds)",
        user: user
      )
    end

    head :ok
  end

  # Fetch list of recordings - Admin only
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

  # Play a specific recording - Admin only
  def play_recording
    recording_sid = params[:sid]

    begin
      recording = Recording.find_by(sid: recording_sid)

      if recording.present?
        # Set cache headers for better performance
        expires_in 1.week, public: true
        
        # Use the URL stored in our database
        media_url = recording.url
        
        # Fetch the recording using Twilio credentials
        response = HTTParty.get(
          media_url,
          basic_auth: {
            username: Rails.application.credentials.dig(:twilio, :account_sid) || Rails.application.credentials.dig(:TWILIO_ACCOUNT_SID),
            password: Rails.application.credentials.dig(:twilio, :auth_token) || Rails.application.credentials.dig(:TWILIO_AUTH_TOKEN)
          }
        )

        # Send the audio data directly to the browser
        send_data response.body, type: 'audio/mpeg', disposition: 'inline'
      else
        # Recording not found
        render plain: "Recording not found", status: :not_found
      end
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

  # Store the current customer ID in the session
  def store_customer_id
    session[:current_call_customer_id] = params[:customer_id]
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
  
  def require_admin
    unless current_user&.admin?
      flash[:error] = "You must be an admin to access recordings"
      redirect_to calling_path
    end
  end
  
  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
end 