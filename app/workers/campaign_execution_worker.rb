class CampaignExecutionWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'campaigns', retry: 3

  def perform(campaign_execution_id)
    campaign_execution = CampaignExecution.find(campaign_execution_id)
    campaign_execution.execute!
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "CampaignExecution ##{campaign_execution_id} not found: #{e.message}"
  end
end
