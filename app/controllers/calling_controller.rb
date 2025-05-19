class CallingController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:voice, :recording_status]
  layout 'dashboard'
  rescue_from StandardError, with: :handle_calling_error

  # Display the browser-based phone interface
  def index
    begin
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
    rescue => e
      Rails.logger.error("Error in calling#index: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      flash.now[:alert] = "Unable to initialize calling service. Please try again later or contact support."
      @customers = Customer.none # Empty relation
      @twilio_numbers = []
    end
  end

  # Generate a capability token
  def token
    begin
      token = twilio_service.generate_capability_token
      render json: { token: token }
    rescue => e
      Rails.logger.error("Error generating token: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: "Unable to generate calling token. Please try again later." }, status: :service_unavailable
    end
  end

  def voice
    begin
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
        # Default user
        user = User.find_by(email: 'sarmad.mansoor@tecaudex.com')
        user_phone_number = user&.phone_number || '+447897021964'
        user_id = user&.id

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
    rescue => e
      Rails.logger.error("Error in voice action: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      
      # Provide a basic TwiML response that informs the caller of the error
      response = Twilio::TwiML::VoiceResponse.new do |r|
        r.say('We are sorry, but there was an error processing your call. Please try again later.', voice: 'alice')
      end
      
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

  # Store customer ID in session for recording association
  def store_customer_id
    session[:current_customer_id] = params[:customer_id]
    render json: { success: true }
  end

  private

  def twilio_service
    @twilio_service ||= TwilioService.new
  end
  
  def handle_calling_error(exception)
    Rails.logger.error("Unhandled exception in CallingController: #{exception.message}")
    Rails.logger.error(exception.backtrace.join("\n"))
    
    respond_to do |format|
      format.html { 
        flash[:alert] = "An error occurred with the calling service. Please try again later."
        redirect_to root_path 
      }
      format.json { render json: { error: "Calling service error" }, status: :internal_server_error }
      format.xml { 
        response = Twilio::TwiML::VoiceResponse.new do |r|
          r.say('We are sorry, but there was an error processing your call. Please try again later.', voice: 'alice')
        end
        render xml: response.to_s
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