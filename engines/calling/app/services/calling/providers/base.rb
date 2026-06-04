module Calling
  module Providers
    # Abstract calling provider. Subclasses adapt a concrete service (Twilio,
    # Plivo, Vonage, …) to this interface. The engine and host code only ever
    # see this contract.
    #
    # Subclasses receive the owning Organization and a decrypted credentials
    # hash sourced from OrganizationFeature#settings.
    class Base
      class NotConfigured < StandardError; end

      attr_reader :organization, :config

      def initialize(organization, config)
        @organization = organization
        @config = (config || {}).with_indifferent_access
      end

      # Browser-side capability/access token for the calling SDK.
      def generate_capability_token(_identity = "web_user")
        raise NotImplementedError
      end

      # Voice response (TwiML for Twilio) the provider's voice webhook returns
      # when a user places an outbound call from the browser.
      def generate_voice_response(_phone_number, _caller_id, _customer_id, _user_id)
        raise NotImplementedError
      end

      # Voice response when an inbound call is being routed to a sales rep.
      def call_sales_rep(_caller, _phone_number, _user_id, _customer_id = nil)
        raise NotImplementedError
      end

      # Pick a caller ID, falling back to a default if the requested one
      # isn't verified.
      def get_verified_caller_id(_requested_caller_id = nil)
        raise NotImplementedError
      end

      # Caller IDs the org may dial out from.
      def fetch_available_numbers
        raise NotImplementedError
      end

      # List the provider's recordings (used by admin tooling, not the
      # primary recording list which lives in the database).
      def fetch_recordings(_limit = 20)
        raise NotImplementedError
      end

      # Fetch metadata only (no auth payload).
      def fetch_recording_metadata(_sid)
        raise NotImplementedError
      end

      # Fetch a single recording's playback metadata + auth.
      def fetch_recording(_sid)
        raise NotImplementedError
      end

      # The provider name as stored in OrganizationFeature#provider.
      def self.provider_name
        name.demodulize.underscore
      end

      private

      def required!(*keys)
        missing = keys.reject { |k| config[k].present? }
        return if missing.empty?

        raise NotConfigured,
              "Calling provider #{self.class.provider_name} is missing credentials: #{missing.join(', ')}"
      end
    end
  end
end
