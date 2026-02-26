class MilestoneItem < ApplicationRecord
  belongs_to :milestone
  has_many :invoice_line_items, dependent: :nullify

  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
