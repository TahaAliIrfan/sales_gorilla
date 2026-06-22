module OdooPortal
  # After a Gmail sync, if the user's org watches the portal and a freshly
  # synced email looks like an Odoo lead notification, kick a portal fetch.
  class EmailTrigger
    LOOKBACK = 10.minutes

    def initialize(user)
      @user = user
    end

    def call
      org = @user.organizations.find { |o| OdooPortalConnection.for_organization(o)&.active? }
      return false unless org

      conn = OdooPortalConnection.for_organization(org)
      return false unless recent_match?(org, conn)

      OdooPortalSyncWorker.perform_async(org.id)
      true
    end

    private

    def recent_match?(org, conn)
      scope = Email.where(organization_id: org.id).where("created_at > ?", LOOKBACK.ago)
      scope = scope.where("from_email ILIKE ?", "%#{conn.watch_from}%") if conn.watch_from.present?
      scope = scope.where("subject ILIKE ?", "%#{conn.watch_subject}%") if conn.watch_subject.present?
      scope.exists?
    end
  end
end
