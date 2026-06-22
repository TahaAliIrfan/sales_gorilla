require "rails_helper"

RSpec.describe DemoGuidePdfService do
  let(:org) { create(:organization) }
  let(:customer) { ActsAsTenant.with_tenant(org) { create(:customer, organization: org, company: "Nurikon", demo_url: "https://demo.tecaudex.pk", demo_login: "admin") } }

  it "renders the guide HTML with the demo coordinates" do
    html = described_class.new(customer).render_html
    expect(html).to include("Nurikon")
    expect(html).to include("https://demo.tecaudex.pk")
    expect(html).to include("admin")
  end

  it "produces a PDF via Grover" do
    grover = instance_double(Grover, to_pdf: "%PDF-1.4 fake")
    allow(Grover).to receive(:new).and_return(grover)
    expect(described_class.call(customer)).to start_with("%PDF")
  end
end
