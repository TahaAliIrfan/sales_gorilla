# Builds a branded Odoo demo for a lead via the demo server, stores its
# coordinates on the Customer, then triggers the story-guide PDF. Runs without a
# tenant (background), so it re-establishes the org explicitly. retry: 1 — a
# failed build is marked failed rather than retried into a storm.
class BuildDemoWorker
  include Sidekiq::Worker
  sidekiq_options queue: "followups", retry: 1

  def perform(customer_id)
    customer = ActsAsTenant.without_tenant { Customer.find_by(id: customer_id) }
    return unless customer

    org = ActsAsTenant.without_tenant { customer.organization }
    ActsAsTenant.with_tenant(org) do
      customer.update!(demo_status: "building")
      begin
        result = DemoBuilderService.call(customer)
      rescue StandardError => e
        Rails.logger.warn("[BuildDemo] customer=#{customer.id} failed: #{e.message}")
        customer.update!(demo_status: "failed")
        next
      end
      customer.update!(
        demo_url: result["url"], demo_db: result["db"],
        demo_login: result["login"], demo_password: result["password"],
        demo_status: "ready", demo_built_at: Time.current
      )
      GenerateDemoGuideWorker.perform_async(customer.id)
    end
  end
end
