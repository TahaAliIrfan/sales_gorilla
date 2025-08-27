class EnhancedPhoneAnalysisWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'default', retry: 3

  def perform(customer_id)
    customer = Customer.find_by(id: customer_id)
    return unless customer.present? && customer.phone.present?

    Rails.logger.info("Starting enhanced phone analysis for customer #{customer_id} with phone #{customer.phone}")
    
    begin
      # Use the new PhoneLocationService for comprehensive analysis
      phone_service = PhoneLocationService.new(customer.phone)
      analysis_result = phone_service.analyze
      
      if analysis_result[:success]
        # Update customer with the comprehensive data
        customer.update_from_phone_analysis(analysis_result)
        
        Rails.logger.info("Successfully completed enhanced phone analysis for customer #{customer_id}")
        
        # Log the analysis results for debugging
        Rails.logger.debug("Enhanced phone analysis results for customer #{customer_id}: #{analysis_result[:data].to_json}")
      else
        Rails.logger.error("Enhanced phone analysis failed for customer #{customer_id}: #{analysis_result[:error]}")
        
        # Fallback to basic analysis or mark as failed
        mark_analysis_failed(customer, analysis_result[:error])
      end
      
    rescue => e
      Rails.logger.error("Error in EnhancedPhoneAnalysisWorker for customer #{customer_id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      
      # Mark analysis as failed with error details
      mark_analysis_failed(customer, e.message)
      
      raise
    end
  end

  private

  def mark_analysis_failed(customer, error_message)
    begin
      customer.update!(
        phone_analysis_completed_at: Time.current,
        phone_analysis_version: '1.0_failed'
      )
      
      # Create a customer activity record for the failure
      customer.customer_activities.create!(
        action: 'Phone Analysis Failed',
        details: "Enhanced phone analysis failed: #{error_message}",
        user_id: customer.user_id || User.first&.id
      )
      
      Rails.logger.warn("Marked phone analysis as failed for customer #{customer.id}")
    rescue => e
      Rails.logger.error("Failed to mark analysis as failed for customer #{customer.id}: #{e.message}")
    end
  end
end