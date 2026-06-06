class LeadScoringWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 3
  
  def perform(customer_id)
    if customer_id
      customer = Customer.find(customer_id)
      scoring_service = LeadScoringService.new(customer)
      scoring_service.calculate_score
    end
  end
end