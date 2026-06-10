require "twilio-ruby"

module Calling
  module Providers
    # Twilio adapter for the Calling engine. Reads its credentials from the
    # per-organization OrganizationFeature#settings hash supplied at init.
    class Twilio < Base
      ALLOWED_US_NUMBER = "+16562700320".freeze

      # Base URL used for Twilio status callbacks (recordings). Defaults from
      # config below, but the controller overrides it with the live request
      # host so callbacks always hit the correct tenant domain.
      attr_accessor :app_url

      def initialize(organization, config)
        super
        required!(:account_sid, :auth_token, :application_sid)

        # Pull from @config (indifferent-access copy made by Base#initialize);
        # the raw `config` parameter has string keys only and symbol lookups
        # silently return nil.
        @account_sid     = @config[:account_sid]
        @auth_token      = @config[:auth_token]
        @api_key         = @config[:api_key]
        @api_secret      = @config[:api_secret]
        @application_sid = @config[:application_sid]
        @default_caller_id = @config[:default_caller_id].presence || "+447897021964"

        @client = ::Twilio::REST::Client.new(@account_sid, @auth_token)
        @app_url = @config[:app_url].presence || "https://crm.tecaudex.com"
      end

      def generate_capability_token(identity = "web_user")
        api_key = @api_key.presence || @account_sid
        api_secret = @api_secret.presence || @auth_token

        token = ::Twilio::JWT::AccessToken.new(
          @account_sid,
          api_key,
          api_secret,
          identity: identity,
          ttl: 3600
        )

        voice_grant = ::Twilio::JWT::AccessToken::VoiceGrant.new
        voice_grant.outgoing_application_sid = @application_sid
        voice_grant.incoming_allow = true

        token.add_grant(voice_grant)

        token.to_jwt
      rescue => e
        Rails.logger.error("Error generating access token: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        raise "Unable to initialize phone service. Please try again later."
      end

      def generate_voice_response(phone_number, caller_id, customer_id, user_id)
        verified_caller_id = get_verified_caller_id(caller_id)

        Rails.logger.info("Voice TwiML - To: #{phone_number}, CallerId: #{verified_caller_id}, CustomerId: #{customer_id}, UserId: #{user_id}")

        ::Twilio::TwiML::VoiceResponse.new do |r|
          if phone_number
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
        ::Twilio::TwiML::VoiceResponse.new { |r| r.say("An error occurred while processing your call.") }
      end

      def get_verified_caller_id(requested_caller_id = nil)
        if requested_caller_id.present?
          available_numbers = fetch_available_numbers
          if available_numbers.any? { |n| n[:phone_number] == requested_caller_id }
            return requested_caller_id
          end

          Rails.logger.warn("Requested caller_id #{requested_caller_id} not found in verified numbers, using default")
        end

        @default_caller_id
      end

      def call_sales_rep(caller, phone_number, user_id, customer_id = nil)
        ::Twilio::TwiML::VoiceResponse.new do |r|
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
        ::Twilio::TwiML::VoiceResponse.new { |r| r.say("An error occurred while processing your call.") }
      end

      def fetch_recordings(limit = 20)
        @client.recordings.list(limit: limit).map do |recording|
          {
            sid: recording.sid,
            duration: recording.duration,
            date: recording.date_created,
            url: "#{@app_url}/calling/play_recording/#{recording.sid}",
            call_sid: recording.call_sid
          }
        end
      rescue ::Twilio::REST::RestError => e
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
      rescue ::Twilio::REST::RestError => e
        Rails.logger.error "Error fetching recording metadata #{recording_sid}: #{e.message}"
        raise e
      end

      def fetch_recording(recording_sid)
        recording = @client.recordings(recording_sid).fetch

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
      rescue ::Twilio::REST::RestError => e
        Rails.logger.error "Error fetching recording #{recording_sid}: #{e.message}"
        raise e
      end

      def fetch_available_numbers
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
end

Calling.register_provider("twilio", Calling::Providers::Twilio)
