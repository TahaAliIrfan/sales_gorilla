require "rails_helper"

RSpec.describe BuildDemoWorker, :sidekiq_fake do
  let(:org) { create(:organization) }
  let(:customer) { ActsAsTenant.with_tenant(org) { create(:customer, organization: org, company: "Nurikon") } }

  it "stores the demo coordinates and marks it ready" do
    allow(DemoBuilderService).to receive(:call).and_return(
      "url" => "https://demo.tecaudex.pk/web?db=lead", "db" => "lead", "login" => "admin", "password" => "p"
    )
    described_class.new.perform(customer.id)
    c = ActsAsTenant.with_tenant(org) { Customer.find(customer.id) }
    expect(c).to have_attributes(demo_url: "https://demo.tecaudex.pk/web?db=lead", demo_db: "lead",
                                 demo_login: "admin", demo_status: "ready")
    expect(c.demo_password).to eq("p")
    expect(c.demo_built_at).to be_present
  end

  it "enqueues the guide-PDF worker after a successful build" do
    allow(DemoBuilderService).to receive(:call).and_return({ "url" => "u" })
    expect { described_class.new.perform(customer.id) }
      .to change(GenerateDemoGuideWorker.jobs, :size).by(1)
  end

  it "marks the demo failed when the build raises" do
    allow(DemoBuilderService).to receive(:call).and_raise(Demo::ServerClient::BuildError, "boom")
    described_class.new.perform(customer.id)
    expect(ActsAsTenant.with_tenant(org) { Customer.find(customer.id) }.demo_status).to eq("failed")
  end
end
