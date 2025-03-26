class StoreRecordingJob < ApplicationJob
  queue_as :default
  
  def perform(recording_id)
    recording = Recording.find_by(id: recording_id)
    return unless recording
    
    RecordingStorageService.download_and_store(recording)
  end
end 