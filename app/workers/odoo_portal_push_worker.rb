# Pushes a CRM status change into the partner portal (note / exception / stage)
# via the saved session. Resolves the lead URL from the PartnerPortalLead row.
class OdooPortalPushWorker
  include Sidekiq::Worker
  sidekiq_options queue: "followups", retry: 3

  def perform(customer_id)
    customer = ActsAsTenant.without_tenant { Customer.find_by(id: customer_id) }
    return unless customer&.portal_lead_id.present?

    org  = ActsAsTenant.without_tenant { customer.organization }
    conn = OdooPortalConnection.for_organization(org)
    return unless conn&.active?

    ActsAsTenant.with_tenant(org) do
      action = OdooPortal::EventMap.action_for(customer)
      next unless action

      lead = PartnerPortalLead.find_by(organization: org, portal_lead_id: customer.portal_lead_id)
      url  = lead&.raw_payload.to_h["url"]
      next unless url

      OdooPortal::Writer.new(conn).perform(url: url, action: action)
      customer.update_columns(portal_last_pushed_at: Time.current)
    end
  rescue OdooPortal::BrowserRunner::SessionExpired
    OdooPortalConnection.for_organization(org)&.mark_needs_reauth!
  end
end
