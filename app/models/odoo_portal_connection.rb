# A partner's authenticated odoo.com portal session, captured once via the
# connect flow and reused by the headless scraper/writer. Mirrors
# MetaPageConnection: per-org routing + encrypted secret + health status.
class OdooPortalConnection < ApplicationRecord
  belongs_to :organization
  acts_as_tenant :organization

  encrypts :session_cookies

  STATUSES = %w[active needs_reauth error].freeze

  validates :base_url, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }

  def self.for_organization(org)
    ActsAsTenant.without_tenant { find_by(organization_id: org.id) }
  end

  def active? = status == "active"

  def cookies
    JSON.parse(session_cookies.presence || "[]")
  rescue JSON::ParserError
    []
  end

  def mark_needs_reauth!
    update_columns(status: "needs_reauth", session_cookies: nil)
  end

  def mark_error!(message)
    update_columns(status: "error", last_error: message.to_s.truncate(1000))
  end

  def touch_synced!
    update_columns(last_synced_at: Time.current, last_error: nil)
  end
end
