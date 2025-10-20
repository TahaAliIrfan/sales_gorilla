class WhatsappMessage < ApplicationRecord
  belongs_to :customer
  
  validates :message_id, presence: true, uniqueness: true
  validates :direction, presence: true, inclusion: { in: ['inbound', 'outbound'] }
end
