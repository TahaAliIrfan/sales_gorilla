namespace :recordings do
  desc "Rename existing S3 recordings to use client name and timestamp format"
  task rename_s3: :environment do
    recordings = Recording.joins(:audio_file_attachment)
    total = recordings.count
    
    puts "Starting renaming of #{total} recordings in S3 to new format..."
    
    renamed_count = 0
    
    recordings.find_each.with_index(1) do |recording, index|
      print "Processing recording #{index}/#{total} (SID: #{recording.sid})... "
      
      begin
        current_filename = recording.audio_file.filename.to_s
        RecordingStorageService.rename_existing_attachment(recording)
        
        if recording.audio_file.filename.to_s != current_filename
          puts "RENAMED from '#{current_filename}' to '#{recording.audio_file.filename}'"
          renamed_count += 1
        else
          puts "SKIPPED - Already using correct naming format"
        end
      rescue => e
        puts "ERROR - #{e.message}"
      end
    end
    
    puts "Renaming completed. #{renamed_count} recordings renamed in S3."
  end
end 