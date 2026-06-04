class RecordingRenameWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3, queue: "recordings"

  def perform(recording_id)
    # Find the recording
    recording = Recording.find_by(id: recording_id)

    # Return early if recording not found or doesn't have attached file
    return unless recording && recording.audio_file.attached?

    # Log the renaming attempt
    Rails.logger.info "Renaming recording #{recording.sid} in background job"

    # Call the storage service to handle the renaming
    RecordingStorageService.rename_existing_attachment(recording)
  end
end
