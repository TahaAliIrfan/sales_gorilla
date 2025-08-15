class MetaConversionsApiWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: 'meta_conversions', retry: 3

  def perform(customer_id, event_type, additional_data = {})
    customer = Customer.find_by(id: customer_id)
    return unless customer

    service = MetaConversionsApiService.new
    return unless service.credentials_configured?

    case event_type
    when 'lead'
      service.send_lead_event(customer)
    when 'view_content'
      service.send_view_content_event(customer)
    when 'complete_registration'
      service.send_complete_registration_event(customer)
    when 'contact'
      communication_type = additional_data['communication_type'] || 'unknown'
      service.send_contact_event(customer, communication_type)
    when 'initiate_checkout'
      deal = Deal.find_by(id: additional_data['deal_id']) if additional_data['deal_id']
      service.send_initiate_checkout_event(customer, deal)
    when 'purchase'
      deal = Deal.find_by(id: additional_data['deal_id']) if additional_data['deal_id']
      service.send_purchase_event(customer, deal)
    else
      Rails.logger.warn("Unknown Meta Conversions API event type: #{event_type}")
    end

  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("MetaConversionsApiWorker: Record not found - #{e.message}")
  rescue StandardError => e
    Rails.logger.error("MetaConversionsApiWorker: Error processing event #{event_type} for customer #{customer_id} - #{e.message}")
    raise e # Let Sidekiq handle retries
  end
end