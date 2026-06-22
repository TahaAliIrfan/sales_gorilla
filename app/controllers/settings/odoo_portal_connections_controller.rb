module Settings
  class OdooPortalConnectionsController < TenantController
    layout "relay"
    before_action :require_login
    before_action :authorize_admin

    def create
      conn = OdooPortalConnection.for_organization(current_organization) ||
             OdooPortalConnection.new(organization: current_organization)
      conn.assign_attributes(connection_params)

      # Primary path: email + password -> log in headlessly and capture the
      # session automatically (and re-auth becomes self-healing). Fallback:
      # a directly-pasted cookie jar.
      if conn.credentials? && conn.session_cookies.blank?
        begin
          cookies = OdooPortal::BrowserRunner.new(conn).login(email: conn.login_email, password: conn.login_password)
          conn.session_cookies = cookies.to_json if cookies.present?
        rescue OdooPortal::BrowserRunner::AgentError => e
          conn.status = "error"
          conn.last_error = e.message.to_s.truncate(1000)
          conn.save!
          return redirect_to settings_features_path, alert: "Couldn't connect to the Odoo portal: #{e.message}"
        end
      end

      conn.status = conn.session_cookies.present? ? "active" : "needs_reauth"
      conn.save!
      ensure_lead_source_taxonomy(current_organization)
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
      params.require(:odoo_portal_connection).permit(:base_url, :watch_from, :watch_subject, :session_cookies, :login_email, :login_password)
    end

    def ensure_lead_source_taxonomy(org)
      return if org.taxonomies.exists?(kind: "lead_source", name: "Odoo Partner Portal")
      org.taxonomies.create!(kind: "lead_source", name: "Odoo Partner Portal")
    rescue ActiveRecord::RecordInvalid, ActiveRecord::NotNullViolation => e
      # position may be required — retry with an explicit position
      pos = (org.taxonomies.where(kind: "lead_source").maximum(:position) || 0) + 1
      org.taxonomies.create!(kind: "lead_source", name: "Odoo Partner Portal", position: pos)
    end
  end
end
