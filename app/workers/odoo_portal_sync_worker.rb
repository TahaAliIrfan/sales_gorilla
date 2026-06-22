# Pulls new portal leads for one org and upserts Customers. Runs on the root
# host (no tenant), so it re-establishes the org explicitly. Triggered by the
# email detector, the scheduled poll, or the manual "Sync now" button.
class OdooPortalSyncWorker
  include Sidekiq::Worker
  sidekiq_options queue: "followups", retry: 3

  def perform(organization_id)
    org  = ActsAsTenant.without_tenant { Organization.find_by(id: organization_id) }
    conn = org && OdooPortalConnection.for_organization(org)
    return unless conn&.active?

    ActsAsTenant.with_tenant(org) { sync(org, conn) }
  end

  private

  def sync(org, conn, retried: false)
    known = PartnerPortalLead.where(organization: org).pluck(:portal_lead_id)
    new_leads = OdooPortal::Scraper.new(conn).fetch_new(known_ids: known)

    new_leads.each { |payload| ingest(org, payload) }
    conn.touch_synced!
  rescue OdooPortal::BrowserRunner::SessionExpired
    # Self-healing: if we have stored credentials, re-login once and retry.
    if !retried && conn.refresh_session!
      sync(org, conn, retried: true)
    else
      conn.mark_needs_reauth!
    end
  rescue => e
    conn.mark_error!(e.message)
    raise
  end

  def ingest(org, payload)
    lead = PartnerPortalLead.find_or_create_by!(
      organization: org, portal_lead_id: payload["portal_lead_id"]
    ) do |l|
      l.status      = "received"
      l.raw_payload = payload
    end
    return if lead.status == "processed"

    attrs    = OdooPortal::LeadParser.call(payload)
    customer = upsert_customer(org, attrs)
    lead.mark_processed!(customer)
  rescue ActiveRecord::RecordNotUnique
    nil # concurrent run already ingested this portal_lead_id
  rescue => e
    lead&.mark_failed!(e.message)
    Rails.logger.warn("[OdooPortalSync] lead #{payload['portal_lead_id']} failed: #{e.message}")
  end

  def upsert_customer(org, attrs)
    Customer.find_or_initialize_by(organization: org, portal_lead_id: attrs[:portal_lead_id]).tap do |c|
      c.assign_attributes(attrs.except(:portal_lead_id).merge(status: c.status.presence || "Pending"))
      c.save!
    end
  end
end
