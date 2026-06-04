# Marker base class for controllers that exist only inside an organization
# (tenant subdomain). The tenant guards live in ApplicationController via
# `authorize_tenant_request!`, conditional on the subdomain present check.
class TenantController < ApplicationController
  layout "tenant"
end
