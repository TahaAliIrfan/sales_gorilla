class GoogleAdsConversionWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 3

  def perform(customer_id)
    customer = Customer.find_by(id: customer_id)
    return Rails.logger.warn("Customer #{customer_id} not found") unless customer
    return Rails.logger.warn("Customer #{customer_id} missing click ID or lead quality") unless customer.gclid.present? && customer.lead_quality.present?

    result = GoogleAdsConversionService.new(customer).upload_offline_conversion
    Rails.logger.info("Google Ads conversion for customer #{customer_id}: #{result[:success] ? 'success' : result[:error]}")
  end
end
