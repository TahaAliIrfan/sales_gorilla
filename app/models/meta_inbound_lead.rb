# One inbound lead notification from Meta Lead Ads. Created the moment the
# `leadgen` webhook fires (status "received"), then enriched asynchronously by
# ProcessMetaInboundLeadWorker, which fetches the lead's field_data via the
# Graph API and turns it into a Customer.
#
# The full webhook body lives in `webhook_payload`; the fetched field_data
# (including any custom form questions) lives in `lead_data` — nothing is lost
# even if a field isn't mapped onto the Customer.
class MetaInboundLead < ApplicationRecord
  belongs_to :organization
  belongs_to :customer, optional: true
  acts_as_tenant :organization

  STATUSES = %w[received processed failed duplicate].freeze

  validates :leadgen_id, presence: true,
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

  # The contact answers returned by Graph (`field_data`) reshaped into a flat
  # { field_name => value } hash. Meta returns each entry as
  # { "name" => "...", "values" => ["..."] }.
  def field_values
    Array(lead_data && lead_data["field_data"]).each_with_object({}) do |field, acc|
      next unless field.is_a?(Hash)
      acc[field["name"].to_s] = Array(field["values"]).first
    end
  end
end
