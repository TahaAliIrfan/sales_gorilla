namespace :campaigns do
  desc "Fix stuck campaign by rescheduling"
  task fix_stuck: :environment do
    campaign = Campaign.in_progress.first

    if campaign
      puts "Found campaign: #{campaign.name}"
      puts "Clearing old scheduled jobs..."
      campaign.clear_scheduled_jobs!

      puts "Rescheduling executions..."
      base_time = Time.current
      campaign.campaign_executions.pending.order(:scheduled_at).each_with_index do |execution, index|
        new_scheduled_time = base_time + (index * 30).seconds
        execution.update(scheduled_at: new_scheduled_time)
        puts "  - #{execution.customer.name}: #{new_scheduled_time}"
      end

      puts "Queueing jobs..."
      campaign.campaign_executions.pending.each do |execution|
        CampaignExecutionWorker.perform_at(execution.scheduled_at, execution.id)
      end

      puts "Done! Campaign should start sending now."
    else
      puts "No in_progress campaign found"
    end
  end
end
