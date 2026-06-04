module Calling
  class CallingController < ApplicationController
    skip_before_action :verify_authenticity_token, only: %i[voice recording_status]
    layout "tenant"
    rescue_from StandardError, with: :handle_calling_error

    def index
      @twilio_numbers = provider.fetch_available_numbers

      if current_user&.admin?
        @customers = Customer.where.not(phone: [ nil, "" ]).order(created_at: :desc)
        @users = User.all.order(:name)
      elsif current_user&.manager?
        subordinate_ids = current_user.managed_associates.pluck(:id)
        visible_user_ids = subordinate_ids + [ current_user.id ]
        @customers = Customer.where(user_id: visible_user_ids).where.not(phone: [ nil, "" ]).order(created_at: :desc)
        @users = User.where(id: visible_user_ids).order(:name)
      else
        @customers = Customer.where(user_id: current_user&.id).where.not(phone: [ nil, "" ]).order(created_at: :desc)
        @users = [ current_user ].compact
      end

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
      @customers = Customer.none
      @twilio_numbers = []
    end

    def token
      identity = current_user&.id&.to_s || current_user&.email || "web_user"
      token = provider.generate_capability_token(identity)

      render json: { success: true, data: { token: token } }
    rescue => e
      Rails.logger.error("Error generating token: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { success: false, error: "Unable to generate calling token. Please try again later." },
             status: :service_unavailable
    end

    def voice
      to = params[:To]
      from = params[:From]
      caller_id = params[:caller_id]
      customer_id = params[:customer_id]
      user_id = params[:user_id]

      Rails.logger.info("Incoming call request - To: #{to}, From: #{from}, CallerId: #{caller_id}, CustomerId: #{customer_id}, UserId: #{user_id}")

      is_client_call = from&.start_with?("client:")

      if is_client_call
        customer = if customer_id.present?
                     Customer.find_by(id: customer_id)
                   else
                     Customer.find_by(phone: to)
                   end

        if user_id.present?
          user_id = user_id.to_i
        elsif customer.present? && customer.user_id.present?
          user_id = customer.user_id
        else
          identity = from.gsub("client:", "")
          user_id = identity.to_i > 0 ? identity.to_i : 1
        end

        Rails.logger.info("Client-to-PSTN call - User: #{user_id}, Customer: #{customer_id}")

        if customer.present?
          customer.track_call_attempt!
          UserKpiRecord.track!(user_id, :calls_attempted)
          Rails.logger.info("Call attempt tracked for Customer ID: #{customer.id}, User ID: #{user_id}")
        end

        response = provider.generate_voice_response(to, caller_id, customer&.id, user_id)
        render xml: response.to_s
      else
        customer = Customer.find_by(phone: params[:Caller])
        user = User.find_by(email: "sarmad.mansoor@tecaudex.com")
        user_phone_number = user&.phone_number || "+447897021964"
        user_id = user&.id

        if customer.present?
          if customer.user.present?
            user_phone_number = customer.user.phone_number
            user_id = customer.user_id
          end
        else
          customer = Customer.create(name: "Unknown Caller", phone: params[:Caller])
        end

        Rails.logger.info("PSTN-to-Sales call - Caller: #{params[:Caller]}, Sales Rep: #{user_phone_number}")

        response = provider.call_sales_rep(params[:Caller], user_phone_number, user_id, customer.id)
        render xml: response.to_s
      end
    rescue => e
      Rails.logger.error("Error in voice action: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      response = ::Twilio::TwiML::VoiceResponse.new do |r|
        r.say("An error occurred while processing your call. Please try again later.")
      end

      render xml: response.to_s
    end

    def recording_status
      recording_sid = params[:RecordingSid]
      call_sid = params[:CallSid]
      duration = params[:RecordingDuration].to_i
      url = params[:RecordingUrl]
      customer_id = params[:customer_id]
      user_id = params[:user_id]

      Rails.logger.info("Recording completed - SID: #{recording_sid}, CallSID: #{call_sid}, CustomerId: #{customer_id}, UserId: #{user_id}")

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

        RecordingStorageWorker.perform_async(recording.id)

        customer.customer_activities.create(
          action: "Call Recording",
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

    def available_numbers
      render json: provider.fetch_available_numbers
    end

    def store_customer_id
      session[:current_customer_id] = params[:customer_id]
      render json: { success: true }
    end

    private

    def provider
      @provider ||= current_organization.calling.provider!
    end

    def handle_calling_error(exception)
      Rails.logger.error("Unhandled exception in Calling::CallingController: #{exception.message}")
      Rails.logger.error(exception.backtrace.join("\n"))

      respond_to do |format|
        format.html do
          flash[:alert] = "An error occurred with the calling service. Please try again later."
          redirect_to root_path
        end
        format.json { render json: { error: "Calling service error" }, status: :internal_server_error }
        format.xml do
          response = ::Twilio::TwiML::VoiceResponse.new do |r|
            r.say("We are sorry, but there was an error processing your call. Please try again later.", voice: "alice")
          end
          render xml: response.to_s
        end
      end
    end
  end
end
