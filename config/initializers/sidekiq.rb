require 'sidekiq'
require 'sidekiq-scheduler'

# Configure Sidekiq client
Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

# Configure Sidekiq server
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
  
  # Load the scheduler configuration
  config.on(:startup) do
    schedule_file = Rails.root.join('config', 'sidekiq_scheduler.yml')
    
    if File.exist?(schedule_file)
      Sidekiq.schedule = YAML.load_file(schedule_file)
      Sidekiq::Scheduler.reload_schedule!
    end
  end
end 