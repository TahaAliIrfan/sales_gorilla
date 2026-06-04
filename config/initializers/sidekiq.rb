require "sidekiq"
require "sidekiq-scheduler"

# Propagate the current tenant from the request thread into Sidekiq jobs, so
# acts_as_tenant scoping survives the hop into the worker process.
require "acts_as_tenant/sidekiq"

# Configure Sidekiq client
Sidekiq.configure_client do |config|
  redis_url = if Rails.env.production?
    Rails.application.credentials.dig(:redis, :production_url) || ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
  else
    Rails.application.credentials.dig(:redis, :development_url) || ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
  end

  # ElastiCache Serverless uses cluster mode, need to use hash tags for key grouping
  redis_options = if redis_url.include?("serverless.use1.cache.amazonaws.com")
    {
      url: redis_url,
      ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE },
      namespace: "sidekiq"
    }
  else
    { url: redis_url }
  end

  config.redis = redis_options
end

# Configure Sidekiq server
Sidekiq.configure_server do |config|
  redis_url = if Rails.env.production?
    Rails.application.credentials.dig(:redis, :production_url) || ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
  else
    Rails.application.credentials.dig(:redis, :development_url) || ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
  end

  # ElastiCache Serverless uses cluster mode, need to use hash tags for key grouping
  redis_options = if redis_url.include?("serverless.use1.cache.amazonaws.com")
    {
      url: redis_url,
      ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE },
      namespace: "sidekiq"
    }
  else
    { url: redis_url }
  end

  config.redis = redis_options

  # Load the scheduler configuration
  config.on(:startup) do
    schedule_file = Rails.root.join("config", "sidekiq_scheduler.yml")

    if File.exist?(schedule_file)
      schedule = YAML.load_file(schedule_file) || {}

      if schedule.is_a?(Hash)
        Sidekiq.schedule = schedule
        Sidekiq::Scheduler.reload_schedule!
      else
        Rails.logger.warn "Invalid sidekiq_scheduler.yml format. Expected a hash of jobs."
      end
    end
  end
end
