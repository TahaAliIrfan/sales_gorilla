# Generates and stores the Roman-Urdu call script for a lead. Runs without a
# tenant (background), so it re-establishes the org explicitly.
class GenerateCallScriptWorker
  include Sidekiq::Worker
  sidekiq_options queue: "followups", retry: 3

  def perform(customer_id)
    customer = ActsAsTenant.without_tenant { Customer.find_by(id: customer_id) }
    return unless customer

    org = ActsAsTenant.without_tenant { customer.organization }
    ActsAsTenant.with_tenant(org) do
      script = CallScriptService.call(customer)
      next if script.blank?
      customer.update!(call_script: script, call_script_generated_at: Time.current)
    end
  end
end
