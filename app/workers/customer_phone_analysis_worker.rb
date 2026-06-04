# DEPRECATED: This worker has been replaced by EnhancedPhoneAnalysisWorker
# which uses PhoneLocationService instead of GeminiCustomerAnalysisService
# for more accurate, cost-effective, and reliable phone number analysis.
# TODO: Remove this file after confirming no active jobs are using it.
class CustomerPhoneAnalysisWorker
  include Sidekiq::Worker
  sidekiq_options queue: "default", retry: 3

  def perform(customer_id)
    customer = Customer.find_by(id: customer_id)
    return unless customer.present? && customer.phone.present?

    # Extract the phone number without the + prefix
    phone_number = customer.phone.gsub(/\A\+/, "")

    # Use the GeminiCustomerAnalysisService to analyze the phone number
    analysis_service = GeminiCustomerAnalysisService.new

    # Use the specialized method for timezone and preferred calling time analysis
    results = analysis_service.analyze_phone_for_timezone(phone_number)

    if results.present?
      customer.update(
        country: results[:country] == "N/A" ? customer.country : results[:country],
        timezone: results[:timezone] == "N/A" ? customer.timezone : results[:timezone],
        preferred_calling_time: results[:preferred_calling_time] == "N/A" ? customer.preferred_calling_time : results[:preferred_calling_time]
      )
      # Log the successful analysis
      Rails.logger.info("Successfully analyzed phone for customer #{customer_id}: #{results.to_json}")
    else
      # Log the failure
      Rails.logger.error("Failed to analyze phone for customer #{customer_id}")
    end
  rescue => e
    Rails.logger.error("Error in CustomerPhoneAnalysisWorker for customer #{customer_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
