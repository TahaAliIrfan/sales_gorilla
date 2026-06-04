class InvoiceLineItem < ApplicationRecord
  belongs_to :invoice
  belongs_to :milestone_item, optional: true

  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
