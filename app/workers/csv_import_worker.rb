class CsvImportWorker
  include Sidekiq::Worker

  sidekiq_options queue: "default", retry: 3

  def perform(csv_upload_id, field_mappings, user_id)
    Rails.logger.info "CSV Import Worker started for user #{user_id}"
    Rails.logger.info "CSV upload ID: #{csv_upload_id}"
    Rails.logger.info "Field mappings: #{field_mappings.inspect}"

    begin
      user = User.find(user_id)
      csv_upload = CsvUpload.find(csv_upload_id)

      unless csv_upload.file_exists?
        raise "CSV file not found at #{csv_upload.file_path}"
      end

      # Process the import
      import_service = CsvImportService.new
      result = import_service.import_customers_from_upload(csv_upload, field_mappings, user)

      Rails.logger.info "CSV Import completed: #{result.inspect}"

      # Clean up the upload file after successful processing
      if result[:success]
        csv_upload.destroy
      end

      # Create notification for user
      if result[:success]
        message = "CSV import completed successfully! #{result[:imported_count]} customers imported."
        if result[:skipped_count] > 0
          message += " #{result[:skipped_count]} rows were skipped due to validation errors."
        end

        Notification.create!(
          user: user,
          content: "CSV Import Completed — #{message}",
          notification_type: "system",
          read: false
        )

        if result[:errors].any?
          error_message = "Some rows had errors: #{result[:errors].first(5).join(', ')}"
          Notification.create!(
            user: user,
            content: "CSV Import Warnings — #{error_message}",
            notification_type: "system",
            read: false
          )
        end
      else
        Notification.create!(
          user: user,
          content: "CSV Import Failed — #{result[:error]}",
          notification_type: "system",
          read: false
        )
      end

    rescue => e
      Rails.logger.error "CSV Import Worker Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Create error notification
      Notification.create!(
        user: User.find(user_id),
        content: "CSV Import Error — #{e.message}",
        notification_type: "system",
        read: false
      )

      raise e
    end
  end
end
