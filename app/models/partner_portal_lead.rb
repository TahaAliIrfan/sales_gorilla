# One scraped lead from the partner portal. Created "received", upserted into a
# Customer, then marked processed/failed/duplicate. Mirrors MetaInboundLead.
class PartnerPortalLead < ApplicationRecord
  belongs_to :organization
  belongs_to :customer, optional: true
  acts_as_tenant :organization

  STATUSES = %w[received processed failed duplicate].freeze

  validates :portal_lead_id, presence: true,
            uniqueness: { scope: :organization_id }
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "received") }

  def mark_processed!(customer)
    update!(customer: customer, status: "processed", processed_at: Time.current, error_message: nil)
  end

  def mark_failed!(message)
    update!(status: "failed", processed_at: Time.current, error_message: message.to_s.truncate(1000))
  end

  def mark_duplicate!(customer)
    update!(customer: customer, status: "duplicate", processed_at: Time.current)
  end
end
