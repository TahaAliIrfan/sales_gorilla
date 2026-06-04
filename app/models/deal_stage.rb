class DealStage < ApplicationRecord
  acts_as_tenant(:organization)

  belongs_to :pipeline
  has_many :deals
  has_many :deal_recordings
  
  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true }
  validates :pipeline_id, presence: true
  
  scope :ordered, -> { order(position: :asc) }
  scope :active, -> { where(active: true) }
  scope :for_pipeline, ->(pipeline) { where(pipeline: pipeline) }
  
  default_scope { order(position: :asc) }
end
