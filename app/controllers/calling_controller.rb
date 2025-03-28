class CallingController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:voice, :recording_status]
  layout 'dashboard'

  # Display the browser-based phone interface
  def index
    @twilio_numbers = twilio_service.fetch_available_numbers
    
    # Filter customers by current user unless they're an admin
    if current_user&.admin?
      @customers = Customer.where.not(phone: [nil, ""]).order(created_at: :desc)
      # Load all users for admin filter dropdown
      @users = User.all.order(:name)
    else
      @customers = Customer.where(user_id: current_user&.id).where.not(phone: [nil, ""]).order(created_at: :desc)
      # Non-admin can only see themselves in filter
      @users = [current_user].compact
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
      customer = Customer.find_by(phone: params[:Caller])
      # DEFAULT NUMBER
      user = User.find_by(email: 'sarmad.mansoor@tecaudex.com')
      user_phone_number = '+923246489818'
      user_id = user.id
      # DEFAULT NUMBER END

      if customer.present?
        if customer.user.present?
          user_phone_number = customer.user.phone_number
          user_id = customer.user_id
        end
      else
        customer = Customer.create(name: 'Unknown Caller', phone: params[:Caller])
      end

      response = twilio_service.call_sales_rep(params[:Caller], user_phone_number, user_id, customer.id)
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
      recording = Recording.create(
        sid: recording_sid,
        call_sid: call_sid,
        url: url,
        duration: duration,
        date: Time.current,
        user: user,
        customer: customer
      )

      # Queue the storage process to run in background
      RecordingStorageWorker.perform_async(recording.id)

      customer.customer_activities.create(
        action: 'Call Recording',
        details: "Call recording saved (#{duration} seconds)",
        user: user
      )
    end

    head :ok
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