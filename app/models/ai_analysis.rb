class AiAnalysis < ApplicationRecord
  belongs_to :recording

  validates :recording_id, presence: true
  validates :interest_score, numericality: { 
    only_integer: true, 
    greater_than_or_equal_to: 1, 
    less_than_or_equal_to: 5,
    allow_nil: true
  }

  after_create :update_lead_score_for_interest
  after_update :update_lead_score_for_interest, if: :saved_change_to_interest_score?

  # Scopes for easier querying
  scope :high_interest, -> { where("interest_score >= ?", 4) }
  scope :medium_interest, -> { where(interest_score: [2, 3]) }
  scope :low_interest, -> { where(interest_score: 1) }

  private

  # Updates customer lead score based on interest score
  def update_lead_score_for_interest
    return unless interest_score.present? && interest_score >= 3
    return unless recording&.customer.present?

    customer = recording.customer
    current_score = customer.lead_score || 0
    
    # Calculate increase based on interest score
    increase = case interest_score
               when 3
                 5  # Fixed 5-point increase
               when 4, 5
                 (current_score * 0.30).round  # 30% increase
               else
                 0
               end
    
    new_score = [current_score + increase, 100].min
    customer.update_column(:lead_score, new_score)
  end
end 