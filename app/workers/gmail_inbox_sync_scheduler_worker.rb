# Cron-driven fan-out: enqueues GmailInboxSyncWorker for every connected user
# every 5 minutes. Single source of truth for "who needs syncing" so the cron
# config stays one entry regardless of org size.
#
# We deliberately enqueue (rather than calling perform inline) so each user's
# sync runs in its own Sidekiq job — failures or token-refresh latency on one
# user can't block the rest.
class GmailInboxSyncSchedulerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0, queue: "default"

  def perform
    user_ids = User.where.not(google_token: [ nil, "" ])
                   .where.not(google_refresh_token: [ nil, "" ])
                   .pluck(:id)

    Rails.logger.info("[GmailInboxSync] scheduling sync for #{user_ids.size} connected user(s)")

    user_ids.each_with_index do |user_id, idx|
      # Stagger by a few seconds each so 100 users don't all hit Gmail's API
      # in the same instant. 2s spread = ~3 minutes for 100 users, well within
      # the 5-min cadence.
      GmailInboxSyncWorker.perform_in((idx * 2).seconds, user_id)
    end
  end
end
