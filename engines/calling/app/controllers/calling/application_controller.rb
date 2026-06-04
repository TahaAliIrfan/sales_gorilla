module Calling
  # Base controller for every action inside the Calling engine. Inherits from
  # the host's ApplicationController so it picks up tenant resolution, login
  # checks, Pundit, etc. Gates every request behind the per-organization
  # `calling` feature flag.
  class ApplicationController < ::ApplicationController
    # `isolate_namespace Calling` rebinds URL generation so the engine's
    # SCRIPT_NAME (`/calling`) is propagated into every `*_path` helper called
    # from this controller — including host helpers, which then incorrectly
    # render as `/calling/customers`, `/calling/recordings`, etc. The bridge
    # below forwards host helpers through `main_app`, which resets the routing
    # context and emits unprefixed paths.
    helper Calling::MainAppRoutesHelper
    helper ::ApplicationHelper

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
