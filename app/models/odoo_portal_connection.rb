# A partner's authenticated odoo.com portal session, captured once via the
# connect flow and reused by the headless scraper/writer. Mirrors
# MetaPageConnection: per-org routing + encrypted secret + health status.
class OdooPortalConnection < ApplicationRecord
  belongs_to :organization
  acts_as_tenant :organization

  encrypts :session_cookies
  encrypts :login_password

  STATUSES = %w[active needs_reauth error].freeze

  # True when we can log in headlessly (email + password) to refresh the session
  # automatically — no manual cookie paste, and re-auth is self-healing.
  def credentials?
    login_email.present? && login_password.present?
  end

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

  # Re-login headlessly with stored credentials and refresh the session cookies.
  # Returns true on success. This is what makes re-auth self-healing.
  def refresh_session!
    return false unless credentials?

    cookies = OdooPortal::BrowserRunner.new(self).login(email: login_email, password: login_password)
    return false if cookies.blank?

    update!(session_cookies: cookies.to_json, status: "active", last_error: nil)
    true
  rescue OdooPortal::BrowserRunner::AgentError => e
    update_columns(status: "error", last_error: e.message.to_s.truncate(1000))
    false
  end
end
