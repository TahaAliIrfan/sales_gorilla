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

  # Helper methods for working with JSONB transcription data
  def full_transcript
    return nil unless transcribed?
    transcription.dig('results', 'channels', 0, 'alternatives', 0, 'transcript')
  end

  def transcript_by_speaker
    return {} unless transcribed?
    
    words = transcription.dig('results', 'channels', 0, 'alternatives', 0, 'words') || []
    words.group_by { |word| word['speaker'] }.transform_values do |speaker_words|
      speaker_words.map { |w| w['punctuated_word'] }.join(' ')
    end
  end

  def transcript_metadata
    return nil unless transcribed?
    transcription['metadata']
  end

  def transcript_confidence
    return nil unless transcribed?
    transcription.dig('results', 'channels', 0, 'alternatives', 0, 'confidence')
  end

  def transcript_words
    return [] unless transcribed?
    transcription.dig('results', 'channels', 0, 'alternatives', 0, 'words') || []
  end
end
