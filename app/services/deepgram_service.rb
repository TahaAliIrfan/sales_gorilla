class DeepgramService
  def self.transcribe_audio(recording)
    begin
      Rails.logger.info "Starting transcription for recording #{recording.sid}"
      
      # Fetch the API key from credentials
      api_key = Rails.application.credentials.dig(:DEEPGRAM_API)
      
      unless api_key
        Rails.logger.error "Deepgram API key not found in credentials"
        return { success: false, error: "API key not found" }
      end
      
      # Make sure recording has audio file attached
      unless recording.audio_file.attached?
        Rails.logger.error "Cannot transcribe recording #{recording.sid}: No audio file attached"
        recording.update(transcription_status: "failed")
        return { success: false, error: "No audio file attached" }
      end
      
      # Set transcription status to processing
      recording.update(transcription_status: "processing")
      
      # Download the audio file to a temporary file
      audio_file = recording.audio_file
      tempfile = Tempfile.new(['recording', '.mp3'])
      tempfile.binmode
      tempfile.write(audio_file.download)
      tempfile.rewind
      
      # Prepare the request to Deepgram API
      url = "https://api.deepgram.com/v1/listen"
      
      # Create headers with authorization
      headers = {
        "Authorization" => "Token #{api_key}",
        "Content-Type" => "audio/mpeg"
      }
      
      # Set parameters for the Deepgram API
      query_params = {
        "punctuate" => true,
        "diarize" => true,
        "model" => "general",
        "language" => "en-US"
      }
      
      # Make the API request to Deepgram
      response = HTTParty.post(
        "#{url}?#{query_params.to_query}",
        headers: headers,
        body: File.read(tempfile.path)
      )
      
      # Process the API response
      if response.success?
        data = JSON.parse(response.body)
        
        # Extract the transcription from the response
        if data["results"] && data["results"]["channels"] && data["results"]["channels"].any?
          # Get the transcript from the first alternative of the first channel
          transcript = data["results"]["channels"][0]["alternatives"][0]["transcript"]
          
          # Update the recording with the transcription
          recording.update(
            transcription: transcript,
            transcription_status: "completed"
          )
          
          Rails.logger.info "Transcription completed for recording #{recording.sid}"
          return { success: true, transcript: transcript }
        else
          Rails.logger.error "No transcript found in Deepgram response for recording #{recording.sid}"
          recording.update(transcription_status: "failed")
          return { success: false, error: "No transcript found in response" }
        end
      else
        error_message = response.body.present? ? JSON.parse(response.body)["error"] : "API request failed"
        Rails.logger.error "Deepgram API error for recording #{recording.sid}: #{error_message}"
        recording.update(transcription_status: "failed")
        return { success: false, error: error_message }
      end
    rescue => e
      Rails.logger.error "Error transcribing recording #{recording.sid}: #{e.message}"
      recording.update(transcription_status: "failed")
      return { success: false, error: e.message }
    ensure
      # Clean up the temporary file
      tempfile&.close
      tempfile&.unlink
    end
  end
end 