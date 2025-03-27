class RecordingStorageService
  def self.download_and_store(recording)
    return if recording.audio_file.attached?
    
    begin
      # Initialize Twilio client
      twilio_service = TwilioService.new
      recording_data = twilio_service.fetch_recording(recording.sid)
      
      # Download the recording file from Twilio
      response = HTTParty.get(
        recording_data[:media_url],
        basic_auth: recording_data[:auth]
      )
      
      if response.success?
        # Create a tempfile to store the audio content
        tempfile = Tempfile.new(['recording', '.mp3'])
        tempfile.binmode
        tempfile.write(response.body)
        tempfile.rewind
        
        # Create filename using standard format
        filename = generate_filename(recording)
        
        # Attach the file to the recording using ActiveStorage
        recording.audio_file.attach(
          io: tempfile,
          filename: filename,
          content_type: 'audio/mpeg'
        )
        
        Rails.logger.info "Recording #{recording.sid} successfully stored in S3 as #{filename}"
        
        # After successfully storing the recording, transcribe it using Deepgram
        if recording.audio_file.attached?
          # Call the Deepgram service to transcribe the audio
          DeepgramService.transcribe_audio(recording)
        end
      else
        Rails.logger.error "Failed to download recording #{recording.sid} from Twilio: #{response.code}"
      end
    rescue => e
      Rails.logger.error "Error downloading and storing recording #{recording.sid}: #{e.message}"
    ensure
      tempfile&.close
      tempfile&.unlink
    end
  end
  
  # Method to rename existing attachment to new naming convention
  def self.rename_existing_attachment(recording)
    return unless recording.audio_file.attached?
    
    begin
      # Get the current attachment's blob
      blob = recording.audio_file.blob
      
      # Generate the new filename using the standard format
      new_filename = generate_filename(recording)
      
      # If filename is already in the new format, skip
      return if blob.filename.to_s == new_filename
      
      # Download the current file
      tempfile = Tempfile.new(['recording', '.mp3'])
      tempfile.binmode
      tempfile.write(blob.download)
      tempfile.rewind
      
      # Delete the old attachment
      recording.audio_file.purge
      
      # Re-attach with new filename
      recording.audio_file.attach(
        io: tempfile,
        filename: new_filename,
        content_type: 'audio/mpeg'
      )
      
      Rails.logger.info "Recording #{recording.sid} renamed to #{new_filename} in S3"
    rescue => e
      Rails.logger.error "Error renaming recording #{recording.sid}: #{e.message}"
    ensure
      tempfile&.close
      tempfile&.unlink
    end
  end
  
  # Standardized filename generator
  def self.generate_filename(recording)
    # Format the timestamp
    timestamp = recording.date.strftime('%Y%m%d_%H%M%S')
    
    # Format client name - remove special characters and replace spaces with underscores
    # Use "Unknown_Client" if customer name is missing or blank
    customer_name = recording.customer&.name.presence || "Unknown_Client"
    client_name = customer_name.gsub(/[^0-9A-Za-z\s]/, '').gsub(/\s+/, '_')
    
    # Format user name (sales rep)
    # Use "Unknown_User" if user name is missing or blank
    user_name = recording.user&.name.presence || "Unknown_User"
    sales_rep = user_name.gsub(/[^0-9A-Za-z\s]/, '').gsub(/\s+/, '_')
    
    # Create a filename with client name, sales rep, and timestamp
    # Format: ClientName_SalesRep_YYYYMMDD_HHMMSS.mp3
    "#{client_name}_#{sales_rep}_#{timestamp}.mp3"
  end
end 