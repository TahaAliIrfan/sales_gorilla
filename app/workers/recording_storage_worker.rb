class RecordingStorageWorker
  include Sidekiq::Worker
  
  sidekiq_options retry: 3, queue: 'recordings'
  
  def perform(recording_id)
    # Find the recording
    recording = Recording.find_by(id: recording_id)
    
    # Return early if recording not found or already has attached file
    return unless recording && !recording.audio_file.attached?
    
    # Log the processing attempt
    Rails.logger.info "Processing recording #{recording.sid} in background job"
    
    # Call the storage service to handle the download and storage
    RecordingStorageService.download_and_store(recording)
  end
end 