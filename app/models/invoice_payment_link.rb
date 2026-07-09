class InvoicePaymentLink < ApplicationRecord
  belongs_to :invoice

  validates :label, presence: true
  validates :url, presence: true
end
