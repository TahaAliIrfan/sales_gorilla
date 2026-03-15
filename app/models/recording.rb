class Recording < ApplicationRecord
  belongs_to :user
  belongs_to :customer
  has_many :ai_analyses, dependent: :destroy
  
  validates :sid, presence: true, uniqueness: true
  validates :call_sid, presence: true
  validates :duration, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  
  # Add ActiveStorage attachment for recording file
  has_one_attached :audio_file

  after_create :track_successful_call
  after_create :update_lead_score_for_successful_call
  
  scope :recent, -> { order(date: :desc) }
  
  # Transcription-related scopes
  scope :transcribed, -> { where(transcription_status: "completed") }
  scope :pending_transcription, -> { where(transcription: nil).or(where.not(transcription_status: "completed")) }
  
  def transcribed?
    transcription.present? && transcription_status == "completed"
  end
  
  def latest_ai_analysis
    ai_analyses.order(created_at: :desc).first
  end
  
  private

  def track_successful_call
    return unless customer.present?

    if duration.present? && duration >= 60
      customer.track_successful_call!
      UserKpiRecord.track!(user_id, :connected_calls)
    end
  end

  # Updates customer lead score for successful calls (90+ seconds)
  def update_lead_score_for_successful_call
    return unless customer.present? && duration.present? && duration >= 150

    current_score = customer.lead_score || 0
    new_score = [current_score + 10, 100].min  # Cap at 100

    customer.update_column(:lead_score, new_score)
  end
end
