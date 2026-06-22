module Settings
  class OdooPortalConnectionsController < TenantController
    layout "relay"
    before_action :require_login
    before_action :authorize_admin

    def create
      conn = OdooPortalConnection.for_organization(current_organization) ||
             OdooPortalConnection.new(organization: current_organization)
      conn.assign_attributes(connection_params)
      conn.status = conn.session_cookies.present? ? "active" : "needs_reauth"
      conn.save!
      redirect_to settings_features_path, notice: "Odoo partner portal connected."
    end

    def destroy
      OdooPortalConnection.for_organization(current_organization)&.destroy
      redirect_to settings_features_path, notice: "Odoo partner portal disconnected."
    end

    private

    def authorize_admin
      authorize OrganizationFeature, :update?
    end

    def connection_params
      params.require(:odoo_portal_connection).permit(:base_url, :watch_from, :watch_subject, :session_cookies)
    end
  end
end
