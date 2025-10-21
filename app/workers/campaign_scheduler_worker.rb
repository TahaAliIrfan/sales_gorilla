class CampaignSchedulerWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'campaigns', retry: 3

  def perform(campaign_id)
    puts "=" * 80
    puts "CAMPAIGN SCHEDULER WORKER RUNNING"
    puts "Campaign ID: #{campaign_id}"
    puts "Current Time: #{Time.current}"
    puts "=" * 80

    campaign = Campaign.find(campaign_id)

    puts "Campaign Found: #{campaign.name}"
    puts "Campaign Status: #{campaign.status}"
    puts "Campaign Scheduled At: #{campaign.scheduled_at}"
    puts "Campaign Executions Count: #{campaign.campaign_executions.count}"
    puts "Pending Executions Count: #{campaign.campaign_executions.pending.count}"

    # Execute the campaign if it's scheduled
    if campaign.scheduled?
      puts "Campaign is in SCHEDULED status - Executing now..."
      campaign.execute_now!
      puts "Campaign execute_now! completed"
    else
      puts "WARNING: Campaign is NOT in scheduled status (Status: #{campaign.status})"
    end

    puts "=" * 80

  rescue ActiveRecord::RecordNotFound => e
    puts "ERROR: Campaign ##{campaign_id} not found: #{e.message}"
    Rails.logger.error "Campaign ##{campaign_id} not found: #{e.message}"
  rescue StandardError => e
    puts "ERROR: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
    Rails.logger.error "Error executing scheduled campaign ##{campaign_id}: #{e.message}"
    raise # Re-raise to trigger Sidekiq retry
  end
end
