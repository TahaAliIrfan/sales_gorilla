class Recording < ApplicationRecord
  belongs_to :user
  belongs_to :customer
  
  validates :sid, presence: true, uniqueness: true
  validates :call_sid, presence: true
  validates :duration, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  
  # Add ActiveStorage attachment for recording file
  has_one_attached :audio_file
  
  scope :recent, -> { order(date: :desc) }
  
  # Transcription-related scopes
  scope :transcribed, -> { where(transcription_status: "completed") }
  scope :pending_transcription, -> { where(transcription: nil).or(where.not(transcription_status: "completed")) }
  
  def transcribed?
    transcription.present? && transcription_status == "completed"
  end
  
  def transcription_failed?
    transcription_status == "failed"
  end
  
  def transcription_pending?
    transcription_status.nil? || transcription_status == "processing"
  end
  
  def request_transcription
    TranscribeRecordingsWorker.perform_async(id) unless transcribed?
  end
end
