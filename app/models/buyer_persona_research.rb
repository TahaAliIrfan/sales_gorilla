class BuyerPersonaResearch < ApplicationRecord
  belongs_to :customer

  STATUSES = %w[pending processing completed failed].freeze

  validates :status, inclusion: { in: STATUSES }

  def pending?    = status == 'pending'
  def processing? = status == 'processing'
  def completed?  = status == 'completed'
  def failed?     = status == 'failed'
end
