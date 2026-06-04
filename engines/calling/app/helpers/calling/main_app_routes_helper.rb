module Calling
  # Bridges host URL helpers into the engine's view context. When the tenant
  # layout (a host file) calls `customers_path`, `recordings_path`, etc. from
  # inside an engine-rendered request, Rails injects the engine's SCRIPT_NAME
  # (`/calling`) into url_options, which then prefixes host paths and produces
  # `/calling/customers`. Routing every host `*_path` / `*_url` through
  # `main_app` resets the routing context and emits unprefixed paths.
  module MainAppRoutesHelper
    PATH_OR_URL = /_(path|url)\z/

    def respond_to_missing?(name, include_private = false)
      if name.to_s.match?(PATH_OR_URL)
        main_app.respond_to?(name, include_private) || super
      else
        super
      end
    end

    def method_missing(name, *args, &block)
      if name.to_s.match?(PATH_OR_URL) && main_app.respond_to?(name)
        main_app.public_send(name, *args, &block)
      else
        super
      end
    end
  end
end
