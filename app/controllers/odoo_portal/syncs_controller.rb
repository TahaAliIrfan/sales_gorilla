module OdooPortal
  class SyncsController < TenantController
    layout "relay"
    before_action :require_login
    before_action :authorize_admin

    def create
      org = current_organization
      OdooPortalSyncWorker.perform_async(org.id) if org && OdooPortalConnection.for_organization(org)&.active?
      redirect_back fallback_location: "/settings/features", notice: "Lead sync started."
    end

    private

    def authorize_admin
      authorize OrganizationFeature, :update?
    end
  end
end
