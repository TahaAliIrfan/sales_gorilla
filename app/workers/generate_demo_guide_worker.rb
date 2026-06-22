# Generates the demo story-guide PDF for a lead and attaches it to the Customer.
class GenerateDemoGuideWorker
  include Sidekiq::Worker
  sidekiq_options queue: "followups", retry: 2

  def perform(customer_id)
    customer = ActsAsTenant.without_tenant { Customer.find_by(id: customer_id) }
    return unless customer

    org = ActsAsTenant.without_tenant { customer.organization }
    ActsAsTenant.with_tenant(org) do
      pdf = DemoGuidePdfService.call(customer)
      next if pdf.blank?
      customer.demo_guide.attach(
        io: StringIO.new(pdf), filename: "demo-guide-#{customer.id}.pdf", content_type: "application/pdf"
      )
    end
  end
end
