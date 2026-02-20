class GoogleAdsConversionWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 3

  def perform(customer_id)
    customer = Customer.find_by(id: customer_id)
    
    unless customer
      Rails.logger.error("GoogleAdsConversionWorker: Customer #{customer_id} not found")
      return
    end

    unless customer.lead_quality.present?
      Rails.logger.warn("GoogleAdsConversionWorker: Customer #{customer_id} has no lead quality set")
      return
    end

    unless customer.gclid.present? || customer.gbraid.present? || customer.wbraid.present?
      Rails.logger.warn("GoogleAdsConversionWorker: Customer #{customer_id} has no Google click ID")
      return
    end

    service = GoogleAdsConversionService.new(customer)
    result = service.upload_offline_conversion

    if result[:success]
      Rails.logger.info("GoogleAdsConversionWorker: Successfully processed conversion for customer #{customer_id} - status: #{result[:status]}")
    else
      Rails.logger.error("GoogleAdsConversionWorker: Failed to process conversion for customer #{customer_id} - error: #{result[:error]}")
    end
  end
end
