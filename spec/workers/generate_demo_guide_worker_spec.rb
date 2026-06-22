require "rails_helper"

RSpec.describe GenerateDemoGuideWorker do
  let(:org) { create(:organization) }
  let(:customer) { ActsAsTenant.with_tenant(org) { create(:customer, organization: org) } }

  it "attaches the generated PDF to the customer" do
    allow(DemoGuidePdfService).to receive(:call).and_return("%PDF-1.4 fake")
    described_class.new.perform(customer.id)
    c = ActsAsTenant.with_tenant(org) { Customer.find(customer.id) }
    expect(c.demo_guide).to be_attached
  end
end
