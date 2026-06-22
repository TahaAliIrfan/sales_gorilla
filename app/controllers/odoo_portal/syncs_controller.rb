module OdooPortal
  class SyncsController < ApplicationController
    def create
      org = ActsAsTenant.current_tenant
      OdooPortalSyncWorker.perform_async(org.id) if org && OdooPortalConnection.for_organization(org)&.active?
      redirect_back fallback_location: "/settings/features", notice: "Lead sync started."
    end
  end
end
