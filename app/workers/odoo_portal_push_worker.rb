class OdooPortalPushWorker
  include Sidekiq::Worker
  sidekiq_options queue: "followups", retry: 3
  def perform(_customer_id); end
end
