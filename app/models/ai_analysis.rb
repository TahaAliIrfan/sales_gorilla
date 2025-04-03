class AiAnalysis < ApplicationRecord
  belongs_to :recording

  validates :recording_id, presence: true
  validates :interest_score, numericality: { 
    only_integer: true, 
    greater_than_or_equal_to: 1, 
    less_than_or_equal_to: 5,
    allow_nil: true
  }

  # Scopes for easier querying
  scope :high_interest, -> { where("interest_score >= ?", 4) }
  scope :medium_interest, -> { where(interest_score: [2, 3]) }
  scope :low_interest, -> { where(interest_score: 1) }
end 