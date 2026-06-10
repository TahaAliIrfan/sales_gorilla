# A Facebook Page that an organization has connected for Lead Ads ingestion.
# Created during the self-service OAuth flow (Settings > Features > Meta Lead
# Ads) once the page is subscribed to the `leadgen` webhook field.
#
# The incoming webhook only carries `page_id` (not the org), so this row is the
# routing table: page_id -> organization. The webhook controller looks it up
# WITHOUT tenant scope (ActsAsTenant.without_tenant), since no tenant is set on
# the root webhook host.
class MetaPageConnection < ApplicationRecord
  belongs_to :organization
  acts_as_tenant :organization

  encrypts :page_access_token

  STATUSES = %w[active revoked error].freeze

  validates :page_id, presence: true, uniqueness: true
  validates :lead_source, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }

  # Resolves the org that owns a Facebook page, ignoring tenant scope. Used by
  # the webhook receiver, which runs on the root host with no current tenant.
  def self.for_page(page_id)
    ActsAsTenant.without_tenant { active.find_by(page_id: page_id.to_s) }
  end

  def mark_error!(message)
    update_columns(status: "error", last_error: message.to_s.truncate(1000))
  end
end
