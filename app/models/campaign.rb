class Campaign < ApplicationRecord
  STATUSES = %w[draft scheduled in_progress completed failed stopped].freeze

  belongs_to :user
  has_many :campaign_executions, dependent: :destroy
  has_many :customers, through: :campaign_executions

  validates :name, presence: true
  validates :message, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :draft, -> { where(status: 'draft') }
  scope :scheduled, -> { where(status: 'scheduled') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }

  def add_customers(customer_ids)
    return if customer_ids.blank?

    # Calculate scheduled times with random intervals (15-55 seconds)
    base_time = scheduled_at || Time.current
    current_time = base_time

    customer_ids.each do |customer_id|
      # Add random interval between 15 and 55 seconds
      random_interval = rand(15..55)
      current_time = current_time + random_interval.seconds

      campaign_executions.find_or_create_by(customer_id: customer_id) do |execution|
        execution.scheduled_at = current_time
        execution.status = 'pending'
      end
    end

    # Trigger auto-scheduling if conditions are met
    auto_schedule_if_ready
  end

  def schedule_for_later!
    puts "=" * 80
    puts "SCHEDULE FOR LATER - Campaign: #{name} (ID: #{id})"
    puts "Campaign Executions Count: #{campaign_executions.count}"
    puts "Scheduled At: #{scheduled_at}"
    puts "Current Time: #{Time.current}"
    puts "=" * 80

    # Validation checks
    if campaign_executions.empty?
      puts "ERROR: No campaign executions found"
      return false
    end

    if scheduled_at.blank?
      puts "ERROR: scheduled_at is blank"
      return false
    end

    if scheduled_at <= Time.current
      puts "ERROR: scheduled_at is in the past"
      return false
    end

    # Create executions with scheduled times using random intervals
    current_time = scheduled_at
    campaign_executions.pending.order(:id).each_with_index do |execution, index|
      # Add random interval between 15 and 55 seconds (except for first customer)
      if index > 0
        random_interval = rand(15..55)
        current_time = current_time + random_interval.seconds
      end
      execution.update(scheduled_at: current_time)
      puts "Execution #{index + 1}: Customer #{execution.customer.name} at #{current_time}"
    end

    # Update campaign status
    update(status: 'scheduled')
    puts "Campaign status updated to: scheduled"

    # Queue the scheduler worker to trigger at the scheduled time
    job = CampaignSchedulerWorker.perform_at(scheduled_at, id)
    puts "CampaignSchedulerWorker queued for #{scheduled_at}"
    puts "Job ID: #{job}"
    puts "=" * 80

    Rails.logger.info "Campaign '#{name}' (ID: #{id}) scheduled for #{scheduled_at}"
    true
  end

  def execute_now!
    return if campaign_executions.empty?

    # Clear any existing scheduled jobs for this campaign
    clear_scheduled_jobs!

    # Reschedule all pending executions to start now with random intervals (15-55 seconds)
    current_time = Time.current
    campaign_executions.pending.order(:scheduled_at).each do |execution|
      # Add random interval between 15 and 55 seconds
      random_interval = rand(15..55)
      current_time = current_time + random_interval.seconds
      execution.update(scheduled_at: current_time)
    end

    update(status: 'in_progress')

    # Queue all pending executions with their new times
    campaign_executions.pending.each do |execution|
      CampaignExecutionWorker.perform_at(execution.scheduled_at, execution.id)
    end
  end

  def clear_scheduled_jobs!
    require 'sidekiq/api'

    # Get all scheduled jobs
    scheduled_set = Sidekiq::ScheduledSet.new
    execution_ids = campaign_executions.pluck(:id)

    # Find and delete jobs for this campaign's executions
    scheduled_set.each do |job|
      if job.klass == 'CampaignExecutionWorker' && execution_ids.include?(job.args.first)
        job.delete
      end
    end
  end

  def draft?
    status == 'draft'
  end

  def scheduled?
    status == 'scheduled'
  end

  def in_progress?
    status == 'in_progress'
  end

  def completed?
    status == 'completed'
  end

  def check_completion!
    return unless in_progress?

    total = campaign_executions.count
    completed_count = campaign_executions.where(status: %w[completed failed]).count

    update(status: 'completed') if total > 0 && total == completed_count
  end

  def total_recipients
    campaign_executions.count
  end

  def completed_count
    campaign_executions.completed.count
  end

  def failed_count
    campaign_executions.failed.count
  end

  def pending_count
    campaign_executions.pending.count
  end

  def restart!
    return unless completed? || failed? || stopped?

    puts "=" * 80
    puts "RESTARTING CAMPAIGN: #{name} (ID: #{id})"
    puts "Current Status: #{status}"
    puts "Total Executions: #{campaign_executions.count}"
    puts "Completed: #{campaign_executions.completed.count}"
    puts "Failed: #{campaign_executions.failed.count}"
    puts "=" * 80

    # Clear any existing scheduled jobs
    clear_scheduled_jobs!

    # Reset ALL executions (completed, failed, processing) back to pending
    campaign_executions.update_all(
      status: 'pending',
      executed_at: nil,
      error_message: nil
    )

    # Reset campaign status to draft
    update(status: 'draft')

    puts "Campaign restarted - all executions reset to pending"
    puts "Campaign status set to: draft"
    puts "=" * 80

    Rails.logger.info "Campaign '#{name}' has been restarted - all executions reset to pending"
  end

  def failed?
    status == 'failed'
  end

  def stopped?
    status == 'stopped'
  end

  def stop!
    return unless scheduled? || in_progress?

    puts "=" * 80
    puts "STOPPING CAMPAIGN: #{name} (ID: #{id})"
    puts "Current Status: #{status}"
    puts "Pending Executions: #{campaign_executions.pending.count}"
    puts "=" * 80

    # Clear any existing scheduled jobs
    clear_scheduled_jobs!

    # Cancel all pending executions (keep completed/failed as is)
    cancelled_count = campaign_executions.pending.update_all(
      status: 'failed',
      executed_at: Time.current,
      error_message: 'Campaign stopped by user'
    )

    # Update campaign status to stopped
    update(status: 'stopped')

    puts "Campaign stopped - #{cancelled_count} pending executions cancelled"
    puts "Campaign status set to: stopped"
    puts "=" * 80

    Rails.logger.info "Campaign '#{name}' has been stopped - #{cancelled_count} pending executions cancelled"
  end

  private

  def auto_schedule_if_ready
    # Only auto-schedule if:
    # 1. Campaign is in draft status
    # 2. Has a scheduled_at time in the future
    # 3. Has at least one customer added
    return unless draft?
    return unless scheduled_at.present? && scheduled_at > Time.current
    return unless campaign_executions.count > 0

    puts "AUTO-SCHEDULING: Campaign #{name} has #{campaign_executions.count} customers and scheduled_at = #{scheduled_at}"
    schedule_for_later!
  end
end
