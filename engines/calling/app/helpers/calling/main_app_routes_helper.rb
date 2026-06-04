module Calling
  # Bridges host URL helpers into the engine's view context. When the tenant
  # layout (a host file) calls `customers_path`, `recordings_path`, etc. from
  # inside an engine-rendered request, Rails injects the engine's SCRIPT_NAME
  # (`/calling`) into url_options, which then prefixes host paths and produces
  # `/calling/customers`. Routing every host `*_path` / `*_url` through
  # `main_app` resets the routing context and emits unprefixed paths.
  #
  # We also explicitly override `polymorphic_url` / `polymorphic_path` because
  # they're already defined on the view context (so `method_missing` never
  # fires) but the engine's version doesn't know about host-only routes like
  # Active Storage's `rails_blob_url`. `image_tag(@org.logo)` would otherwise
  # raise "undefined method `attachment_url`" when rendered from an engine view.
  module MainAppRoutesHelper
    PATH_OR_URL = /_(path|url)\z/

    def polymorphic_url(*args, **kwargs, &block)
      main_app.polymorphic_url(*args, **kwargs, &block)
    end

    def polymorphic_path(*args, **kwargs, &block)
      main_app.polymorphic_path(*args, **kwargs, &block)
    end

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
