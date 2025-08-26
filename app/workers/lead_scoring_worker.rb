class LeadScoringWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: 3
  
  def perform(customer_id = nil)
    if customer_id
      # Score a specific customer
      customer = Customer.find(customer_id)
      calculate_and_update_lead_score(customer)
    else
      # Score all customers
      score_all_customers
    end
  end
  
  private
  
  def score_all_customers
    Rails.logger.info("Starting lead scoring for all customers")
    
    Customer.find_each(batch_size: 100) do |customer|
      calculate_and_update_lead_score(customer)
    rescue => e
      Rails.logger.error("Failed to calculate lead score for customer #{customer.id}: #{e.message}")
    end
    
    Rails.logger.info("Completed lead scoring for all customers")
  end
  
  def calculate_and_update_lead_score(customer)
    scoring_service = LeadScoringService.new(customer)
    result = scoring_service.calculate_score
    
    customer.update!(
      lead_score: result[:total_score],
      geographic_score: result[:geographic_score],
      description_score: result[:description_score],
      lead_score_updated_at: Time.current
    )
    
    Rails.logger.info("Updated lead score for customer #{customer.id} (#{customer.name}): #{result[:total_score]} (geo: #{result[:geographic_score]}, desc: #{result[:description_score]})")
    
    # Log significant score changes
    if result[:total_score] >= 80
      Rails.logger.info("High-value lead detected: #{customer.name} (#{result[:total_score]}) - #{result[:breakdown]}")
    end
  rescue => e
    Rails.logger.error("Error calculating lead score for customer #{customer.id}: #{e.message}")
    raise e
  end
end