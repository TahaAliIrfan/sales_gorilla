class BulkPhoneAnalysisWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'default', retry: 2

  def perform(batch_size = 50, force_reanalyze = false)
    Rails.logger.info("Starting bulk phone analysis (batch_size: #{batch_size}, force_reanalyze: #{force_reanalyze})")
    
    customers_query = Customer.where.not(phone: [nil, ''])
    
    unless force_reanalyze
      # Only analyze customers that haven't been analyzed yet or failed analysis
      customers_query = customers_query.where(
        phone_analysis_completed_at: nil
      ).or(
        customers_query.where(phone_analysis_version: '1.0_failed')
      )
    end
    
    total_customers = customers_query.count
    processed = 0
    failed = 0
    
    Rails.logger.info("Found #{total_customers} customers for bulk phone analysis")
    
    customers_query.find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |customer|
        begin
          # Queue individual phone analysis jobs
          EnhancedPhoneAnalysisWorker.perform_async(customer.id)
          processed += 1
          
          # Add small delay between jobs to avoid overwhelming external services
          sleep(0.1)
          
        rescue => e
          failed += 1
          Rails.logger.error("Failed to queue phone analysis for customer #{customer.id}: #{e.message}")
        end
      end
      
      Rails.logger.info("Queued phone analysis for #{processed} customers so far...")
      
      # Add a longer pause between batches
      sleep(1) if batch.size == batch_size
    end
    
    Rails.logger.info("Bulk phone analysis completed. Queued: #{processed}, Failed to queue: #{failed}")
    
    # Create a system notification or log entry about the bulk operation
    create_bulk_analysis_summary(total_customers, processed, failed, force_reanalyze)
  end

  private

  def create_bulk_analysis_summary(total, processed, failed, force_reanalyze)
    summary = {
      operation: 'bulk_phone_analysis',
      total_customers: total,
      processed: processed,
      failed_to_queue: failed,
      force_reanalyze: force_reanalyze,
      started_at: Time.current,
      batch_size: 50
    }
    
    # Log the summary
    Rails.logger.info("Bulk phone analysis summary: #{summary.to_json}")
    
    # Optionally create a system notification for admins
    begin
      admin_user = User.joins(:role_assignments)
                      .joins('JOIN roles ON roles.id = role_assignments.role_id')
                      .where(roles: { key: 'admin' })
                      .first
      
      if admin_user
        admin_user.notifications.create!(
          notification_type: 'system',
          content: "Bulk phone analysis completed. Processed #{processed}/#{total} customers.",
          resource_type: 'Customer',
          resource_id: nil
        )
      end
    rescue => e
      Rails.logger.error("Failed to create admin notification for bulk analysis: #{e.message}")
    end
  end
end