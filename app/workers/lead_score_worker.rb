class LeadScoreWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 2

  def perform(customer_id, run_ai = true)
    customer = Customer.find_by(id: customer_id)
    return unless customer

    LeadScoringService.new(customer).refresh!(run_ai: run_ai)
  end
end
