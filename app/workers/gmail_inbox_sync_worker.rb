# Periodic per-user Gmail inbox sync. Pulls every message the user received
# (or sent) since the last sync, resolves each to a Customer via thread-id or
# sender email, and persists an Email record. Idempotent — safe to re-run
# without creating duplicates (process_message dedupes by message_id).
#
# Enqueued every 5 minutes per connected user by GmailInboxSyncSchedulerWorker.
# Customer-level fetches that the UI triggers manually still go through
# CustomerEmailFetchWorker (different scope: search for a specific customer's
# entire thread history, not the last-N-minutes delta).
class GmailInboxSyncWorker
  include Sidekiq::Worker
  sidekiq_options retry: 2, queue: "emails"

  # Soft per-user cooldown so back-to-back enqueues (e.g. scheduler + manual
  # "Sync now" button) don't double up. Shorter than the scheduler cadence.
  COOLDOWN = 90.seconds

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user&.google_auth_configured?

    if user.last_gmail_sync_at.present? && user.last_gmail_sync_at > COOLDOWN.ago
      Rails.logger.info("[GmailInboxSync] cooldown, skipping user=#{user_id}")
      return
    end

    # Initial sync goes 24h back; subsequent syncs walk forward from the cursor.
    # A small 60s overlap protects against clock skew + Gmail's eventual consistency.
    since = user.last_gmail_sync_at.present? ? user.last_gmail_sync_at - 60.seconds : 24.hours.ago

    summary = GmailService.new(user).fetch_new_inbox_since(since)

    user.update_column(:last_gmail_sync_at, Time.current)

    begin
      OdooPortal::EmailTrigger.new(user).call
    rescue => e
      Rails.logger.warn("[OdooPortalEmailTrigger] user=#{user.id}: #{e.message}")
    end

    if summary[:imported].to_i.positive?
      Rails.logger.info("[GmailInboxSync] user=#{user_id} imported=#{summary[:imported]} skipped=#{summary[:skipped]} scanned=#{summary[:scanned]}")
    end
  rescue Google::Apis::AuthorizationError, Signet::AuthorizationError => e
    Rails.logger.warn("[GmailInboxSync] auth error for user=#{user_id}: #{e.message}")
  rescue => e
    Rails.logger.error("[GmailInboxSync] failed for user=#{user_id}: #{e.message}")
    raise
  end
end
