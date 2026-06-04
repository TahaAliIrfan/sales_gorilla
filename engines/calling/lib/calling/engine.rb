module Calling
  class Engine < ::Rails::Engine
    isolate_namespace Calling

    config.generators do |g|
      g.test_framework nil
    end

    # Force-load known provider classes so each one self-registers with the
    # provider registry (`Calling.register_provider`). New providers added to
    # `app/services/calling/providers/` should be added here as well.
    config.to_prepare do
      Calling::Providers::Twilio
    end
  end
end
