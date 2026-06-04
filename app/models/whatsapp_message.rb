class WhatsappMessage < ApplicationRecord
  acts_as_tenant(:organization)

  belongs_to :customer

  # Outbound media (documents/images) sent through the Twilio WhatsApp path.
  has_one_attached :media

  validates :message_id, presence: true, uniqueness: true
  validates :direction, presence: true, inclusion: { in: ['inbound', 'outbound'] }
end
