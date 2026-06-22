# Backstop: enqueue a fetch for every active connection (catches missed emails).
class OdooPortalPollSchedulerWorker
  include Sidekiq::Worker
  sidekiq_options queue: "default", retry: 1

  def perform
    ActsAsTenant.without_tenant do
      OdooPortalConnection.active.pluck(:organization_id).each do |org_id|
        OdooPortalSyncWorker.perform_async(org_id)
      end
    end
  end
end
