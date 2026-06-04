class MetaConversionLog < ApplicationRecord
  acts_as_tenant(:organization)

  belongs_to :customer

  validates :event_name, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
end
