class ServerHealthMonitorWorker
  include Sidekiq::Worker
  sidekiq_options queue: "default", retry: 1

  # Thresholds for alerts
  SLOW_RESPONSE_THRESHOLD = 3.0 # seconds
  HIGH_MEMORY_THRESHOLD = 85 # percentage
  HIGH_CPU_THRESHOLD = 80 # percentage
  SLOW_DATABASE_THRESHOLD = 2.0 # seconds

  # Rate limiting - don't send duplicate alerts within this window
  ALERT_COOLDOWN = 15.minutes

  def perform
    Rails.logger.info("Starting server health check...")

    health_status = {
      timestamp: Time.current,
      checks: {}
    }

    # Check application response time
    app_health = check_application_health
    health_status[:checks][:application] = app_health

    # Check database performance
    db_health = check_database_health
    health_status[:checks][:database] = db_health

    # Check system resources (if available)
    system_health = check_system_resources
    health_status[:checks][:system] = system_health

    # Check Sidekiq health
    sidekiq_health = check_sidekiq_health
    health_status[:checks][:sidekiq] = sidekiq_health

    # Send alerts if issues detected
    send_alerts_if_needed(health_status)

    Rails.logger.info("Health check completed: #{health_status[:checks].map { |k, v| "#{k}=#{v[:status]}" }.join(', ')}")

    health_status
  rescue => e
    Rails.logger.error("Error in ServerHealthMonitorWorker: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    # Send critical alert about monitoring failure
    send_alert_with_cooldown(
      :health_check_failed_alert,
      "health_check_failed",
      "Health monitoring failed: #{e.message}"
    )
  end

  private

  def check_application_health
    start_time = Time.now

    begin
      # Try to connect to database
      ActiveRecord::Base.connection.execute("SELECT 1")

      response_time = Time.now - start_time

      if response_time > SLOW_RESPONSE_THRESHOLD
        {
          status: "slow",
          response_time: response_time.round(3),
          message: "Application responding slowly (#{response_time.round(2)}s)"
        }
      else
        {
          status: "healthy",
          response_time: response_time.round(3),
          message: "Application responding normally"
        }
      end
    rescue => e
      {
        status: "critical",
        error: e.message,
        message: "Application health check failed: #{e.message}"
      }
    end
  end

  def check_database_health
    start_time = Time.now

    begin
      # Run a simple query
      Customer.limit(1).count

      query_time = Time.now - start_time

      if query_time > SLOW_DATABASE_THRESHOLD
        {
          status: "slow",
          query_time: query_time.round(3),
          message: "Database queries slow (#{query_time.round(2)}s)"
        }
      else
        {
          status: "healthy",
          query_time: query_time.round(3),
          message: "Database responding normally"
        }
      end
    rescue => e
      {
        status: "critical",
        error: e.message,
        message: "Database check failed: #{e.message}"
      }
    end
  end

  def check_system_resources
    begin
      # Get basic system info from Redis if available
      redis_info = Sidekiq.redis { |conn| conn.info }

      memory_info = {
        status: "healthy",
        message: "Redis running"
      }

      # Check if we can get memory usage
      if redis_info["used_memory_human"]
        memory_info[:redis_memory] = redis_info["used_memory_human"]
      end

      memory_info
    rescue => e
      {
        status: "warning",
        message: "Could not check system resources: #{e.message}"
      }
    end
  end

  def check_sidekiq_health
    begin
      stats = Sidekiq::Stats.new

      # Check for large queue backlogs
      queue_size = stats.enqueued
      failed_jobs = stats.failed

      if queue_size > 1000
        {
          status: "warning",
          enqueued: queue_size,
          failed: failed_jobs,
          message: "Large Sidekiq queue backlog (#{queue_size} jobs)"
        }
      elsif failed_jobs > 100
        {
          status: "warning",
          enqueued: queue_size,
          failed: failed_jobs,
          message: "High number of failed jobs (#{failed_jobs})"
        }
      else
        {
          status: "healthy",
          enqueued: queue_size,
          failed: failed_jobs,
          message: "Sidekiq running normally"
        }
      end
    rescue => e
      {
        status: "critical",
        message: "Sidekiq check failed: #{e.message}"
      }
    end
  end

  def send_alerts_if_needed(health_status)
    checks = health_status[:checks]

    # Application slow or crashed
    if checks[:application][:status] == "slow"
      send_alert_with_cooldown(
        :server_slow_alert,
        "app_slow",
        "Response time: #{checks[:application][:response_time]}s (threshold: #{SLOW_RESPONSE_THRESHOLD}s)"
      )
    elsif checks[:application][:status] == "critical"
      send_alert_with_cooldown(
        :server_crashed_alert,
        "app_crash",
        checks[:application][:message]
      )
    end

    # Database slow
    if checks[:database][:status] == "slow"
      send_alert_with_cooldown(
        :database_slow_alert,
        "db_slow",
        "Query time: #{checks[:database][:query_time]}s (threshold: #{SLOW_DATABASE_THRESHOLD}s)"
      )
    elsif checks[:database][:status] == "critical"
      send_alert_with_cooldown(
        :database_slow_alert,
        "db_crash",
        checks[:database][:message]
      )
    end

    # Sidekiq issues
    if checks[:sidekiq][:status] == "warning"
      send_alert_with_cooldown(
        :server_slow_alert,
        "sidekiq_backlog",
        checks[:sidekiq][:message]
      )
    elsif checks[:sidekiq][:status] == "critical"
      send_alert_with_cooldown(
        :server_crashed_alert,
        "sidekiq_crash",
        checks[:sidekiq][:message]
      )
    end
  end

  def send_alert_with_cooldown(alert_method, alert_key, message)
    cache_key = "health_alert:#{alert_key}"

    # Check if we recently sent this alert
    if Rails.cache.read(cache_key)
      Rails.logger.info("Skipping duplicate alert: #{alert_key} (cooldown active)")
      return
    end

    # Send the alert
    GoogleChatNotifier.send(alert_method, message)

    # Set cooldown
    Rails.cache.write(cache_key, true, expires_in: ALERT_COOLDOWN)
  end
end
