require "rails_helper"

RSpec.describe GenerateCallScriptWorker do
  let(:org) { create(:organization) }
  let(:customer) { ActsAsTenant.with_tenant(org) { create(:customer, organization: org) } }

  it "writes the generated script and timestamp" do
    allow(CallScriptService).to receive(:call).and_return("Assalam-o-Alaikum Faraz sahab...")
    described_class.new.perform(customer.id)
    c = ActsAsTenant.with_tenant(org) { Customer.find(customer.id) }
    expect(c.call_script).to start_with("Assalam-o-Alaikum")
    expect(c.call_script_generated_at).to be_present
  end

  it "no-ops for a missing customer" do
    expect { described_class.new.perform(-1) }.not_to raise_error
  end
end
