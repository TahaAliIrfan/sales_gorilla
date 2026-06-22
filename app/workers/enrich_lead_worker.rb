# Researches a lead via AI and stores the intel on the Customer, then triggers
# call-script generation. Runs without a tenant (background), so it re-establishes
# the org explicitly.
class EnrichLeadWorker
  include Sidekiq::Worker
  sidekiq_options queue: "followups", retry: 3

  def perform(customer_id)
    customer = ActsAsTenant.without_tenant { Customer.find_by(id: customer_id) }
    return unless customer

    org = ActsAsTenant.without_tenant { customer.organization }
    ActsAsTenant.with_tenant(org) do
      begin
        intel = LeadEnrichmentService.call(customer)
      rescue Ai::Client::MissingKey, Ai::Client::ApiError => e
        Rails.logger.warn("[EnrichLead] customer=#{customer.id} AI unavailable: #{e.message}")
        return
      end
      customer.update!(
        enrichment_summary: intel[:summary],
        industry: intel[:industry],
        legitimacy_score: intel[:legitimacy_score],
        lead_is_junk: intel[:is_junk],
        enriched_at: Time.current
      )
      GenerateCallScriptWorker.perform_async(customer.id)
    end
  end
end
