module Calling
  # Base controller for every action inside the Calling engine. Inherits from
  # the host's ApplicationController so it picks up tenant resolution, login
  # checks, Pundit, etc. Gates every request behind the per-organization
  # `calling` feature flag.
  class ApplicationController < ::ApplicationController
    # `isolate_namespace Calling` swaps URL helpers to engine-scoped ones, but
    # the tenant layout (and any host-rendered partials) reference host paths
    # like `dashboard_path`, `customers_path`, etc. Expose host helpers so those
    # views render correctly. Engine-internal routes are accessed via the engine
    # routes proxy when needed.
    helper Rails.application.routes.url_helpers

    before_action :require_calling_enabled

    private

    def require_calling_enabled
      return if current_organization&.feature_enabled?(:calling)

      respond_to do |format|
        format.html { head :forbidden }
        format.json { render json: { error: "Calling module is not enabled for this organization" }, status: :forbidden }
        format.any  { head :forbidden }
      end
    end
  end
end
