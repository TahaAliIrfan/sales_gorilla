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
      elsif current_user&.manager?
        subordinate_ids = current_user.managed_associates.pluck(:id)
        visible_user_ids = subordinate_ids + [current_user.id]
        @customers = Customer.where(user_id: visible_user_ids).where.not(phone: [nil, ""]).order(created_at: :desc)
        # Manager can filter by themselves or any of their associates
        @users = User.where(id: visible_user_ids).order(:name)
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

  # Generate an access token
  def token
    begin
      # Use current user's ID or email as identity
      identity = current_user&.id&.to_s || current_user&.email || 'web_user'
      token = twilio_service.generate_capability_token(identity)

      render json: {
        success: true,
        data: {
          token: token
        }
      }
    rescue => e
      Rails.logger.error("Error generating token: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: {
        success: false,
        error: "Unable to generate calling token. Please try again later."
      }, status: :service_unavailable
    end
  end

  # Persist the signed-in user's default outbound caller ID. Used by the dialer
  # and the floating call widget, and enforced server-side in #voice.
  def set_default_number
    if current_user && params[:caller_id].present?
      current_user.update(default_caller_id: params[:caller_id])
      render json: { success: true, default_caller_id: current_user.default_caller_id }
    else
      render json: { success: false, error: "No number provided" }, status: :unprocessable_entity
    end
  end

  def voice
    begin
      # Get parameters from Twilio
      to = params[:To]
      from = params[:From]
      caller_id = params[:caller_id]
      customer_id = params[:customer_id]
      user_id = params[:user_id]

      Rails.logger.info("Incoming call request - To: #{to}, From: #{from}, CallerId: #{caller_id}, CustomerId: #{customer_id}, UserId: #{user_id}")

      # Check if this is a client-to-PSTN call (from web/mobile app)
      # Client calls have From starting with "client:"
      is_client_call = from&.start_with?('client:')

      # Handle outgoing calls (from web/mobile client to PSTN)
      if is_client_call
        # Find or create customer
        if customer_id.present?
          customer = Customer.find_by(id: customer_id)
        else
          # Try to find customer by phone number
          customer = Customer.find_by(phone: to)
        end

        # Determine user_id
        if user_id.present?
          user_id = user_id.to_i
        elsif customer.present? && customer.user_id.present?
          user_id = customer.user_id
        else
          # Extract user ID from client identity (e.g., "client:2" -> user_id: 2)
          identity = from.gsub('client:', '')
          user_id = identity.to_i > 0 ? identity.to_i : 1
        end

        # Enforce the caller's saved default number whenever the client didn't
        # send an explicit caller ID — so every call path uses the default.
        caller_id = caller_id.presence || User.find_by(id: user_id)&.default_caller_id || '+447897021964'

        Rails.logger.info("Client-to-PSTN call - User: #{user_id}, Customer: #{customer_id}, CallerId: #{caller_id}")

        # Track call attempt as soon as the call is initiated
        if customer.present?
          customer.track_call_attempt!
          UserKpiRecord.track!(user_id, :calls_attempted)
          Rails.logger.info("Call attempt tracked for Customer ID: #{customer.id}, User ID: #{user_id}")
        end

        response = twilio_service.generate_voice_response(to, caller_id, customer&.id, user_id)
        render xml: response.to_s
      else
        # Handle incoming calls (from PSTN to sales rep)
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

        Rails.logger.info("PSTN-to-Sales call - Caller: #{params[:Caller]}, Sales Rep: #{user_phone_number}")

        response = twilio_service.call_sales_rep(params[:Caller], user_phone_number, user_id, customer.id)
        render xml: response.to_s
      end
    rescue => e
      Rails.logger.error("Error in voice action: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      # Provide a basic TwiML response that informs the caller of the error
      response = Twilio::TwiML::VoiceResponse.new do |r|
        r.say('An error occurred while processing your call. Please try again later.')
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
    customer_id = params[:customer_id]
    user_id = params[:user_id]

    Rails.logger.info("Recording completed - SID: #{recording_sid}, CallSID: #{call_sid}, CustomerId: #{customer_id}, UserId: #{user_id}")

    # Find the customer and user associated with this call
    customer = Customer.find_by(id: customer_id)
    user = User.find_by(id: user_id)

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

      Rails.logger.info("Recording saved to database - ID: #{recording.id}")

      # Queue the storage process to run in background
      RecordingStorageWorker.perform_async(recording.id)

      customer.customer_activities.create(
        action: 'Call Recording',
        details: "Call recording saved (#{duration} seconds)",
        user: user
      )
    else
      Rails.logger.warn("Customer or User not found for recording - CustomerId: #{customer_id}, UserId: #{user_id}")
    end

    render json: { success: true }
  rescue => e
    Rails.logger.error("Error handling recording status: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    render json: { success: false, error: e.message }, status: :internal_server_error
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