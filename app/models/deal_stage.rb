class DealStage < ApplicationRecord
  has_many :deals
  has_many :deal_recordings
  
  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true }
  
  default_scope { order(position: :asc) }
end
