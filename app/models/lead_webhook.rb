# A self-service intake endpoint for external lead sources (Zapier, Meta
# Lead Ads, landing pages). Each webhook gets a unique token; the public
# URL `POST /api/v1/leads/:token` creates Customers tagged with this
# webhook's lead_source — no code changes needed per new campaign/Zap.
class LeadWebhook < ApplicationRecord
  has_secure_token :token, length: 32

  validates :name, presence: true
  validates :lead_source, presence: true, inclusion: { in: Customer::LEAD_SOURCES.values }

  scope :active, -> { where(active: true) }

  def record_success!(payload)
    update_columns(
      leads_count: leads_count + 1,
      last_received_at: Time.current,
      last_payload: payload,
      last_error: nil,
      updated_at: Time.current
    )
  end

  def record_failure!(payload, error_message)
    update_columns(
      last_received_at: Time.current,
      last_payload: payload,
      last_error: error_message.to_s.truncate(255),
      updated_at: Time.current
    )
  end
end
