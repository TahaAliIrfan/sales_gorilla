class GenerateDemoGuideWorker
  include Sidekiq::Worker
  sidekiq_options queue: "followups", retry: 2
  def perform(_customer_id); end # real body in a later task
end
