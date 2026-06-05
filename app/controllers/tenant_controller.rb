# Marker base class for controllers that exist only inside an organization
# (tenant subdomain). The tenant guards live in ApplicationController via
# `authorize_tenant_request!`, conditional on the subdomain present check.
class TenantController < ApplicationController
  # Relay is the only console shell now (the legacy tenant layout was removed).
  # Subclasses already declare `layout "relay"`; this makes the default safe.
  layout "relay"
end
