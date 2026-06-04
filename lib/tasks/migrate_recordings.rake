namespace :recordings do
  desc "Migrate existing Twilio recordings to S3"
  task migrate_to_s3: :environment do
    recordings = Recording.where.not(url: nil).where.missing(:audio_file_attachment)
    total = recordings.count
    
    puts "Starting migration of #{total} recordings to S3..."
    
    recordings.find_each.with_index(1) do |recording, index|
      print "Processing recording #{index}/#{total} (SID: #{recording.sid})... "
      
      begin
        RecordingStorageService.download_and_store(recording)
        
        if recording.audio_file.attached?
          puts "SUCCESS - Stored as #{recording.audio_file.filename}"
        else
          puts "FAILED - Could not attach file"
        end
      rescue => e
        puts "ERROR - #{e.message}"
      end
    end
    
    puts "Migration completed. #{Recording.where.attached(:audio_file).count} recordings stored in S3."
  end
end 