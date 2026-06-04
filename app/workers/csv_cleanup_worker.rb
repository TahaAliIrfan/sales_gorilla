class CsvCleanupWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: 'default', retry: false
  
  def perform
    Rails.logger.info "Starting CSV cleanup job"
    
    expired_count = 0
    CsvUpload.expired.find_each do |upload|
      Rails.logger.info "Cleaning up expired CSV upload: #{upload.upload_token} (#{upload.original_filename})"
      upload.destroy
      expired_count += 1
    end
    
    Rails.logger.info "CSV cleanup completed. Removed #{expired_count} expired uploads."
  end
end