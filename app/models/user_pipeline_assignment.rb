class UserPipelineAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :pipeline
  
  validates :user_id, uniqueness: { scope: :pipeline_id }
  
  scope :active, -> { joins(:pipeline).where(pipelines: { active: true }) }
end