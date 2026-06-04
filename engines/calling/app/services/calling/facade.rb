module Calling
  # Single entry-point the host app uses to interact with the Calling engine.
  # Hides the provider/registry plumbing behind a per-organization object.
  #
  # Example:
  #   org.calling.enabled?            # => true
  #   org.calling.provider            # => Calling::Providers::Twilio instance
  #   org.calling.provider.generate_access_token("web_user")
  class Facade
    attr_reader :organization

    def initialize(organization)
      @organization = organization
    end

    def feature
      @feature ||= organization.feature(:calling)
    end

    def enabled?
      feature&.enabled? || false
    end

    def provider_name
      feature&.provider
    end

    # Returns a configured provider adapter, or nil if calling is disabled
    # or no known provider is selected.
    def provider
      return nil unless enabled?
      return nil if provider_name.blank?

      klass = Calling.providers[provider_name]
      return nil unless klass

      @provider ||= klass.new(organization, feature.settings_hash)
    end

    # Raises if no provider is configured — useful for controller actions
    # that can't gracefully degrade.
    def provider!
      provider || raise(Providers::Base::NotConfigured,
                        "Calling provider not configured for #{organization.subdomain}")
    end
  end
end
