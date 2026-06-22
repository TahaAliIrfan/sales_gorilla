require "rails_helper"

RSpec.describe OdooPortal::LeadParser do
  let(:html) { Rails.root.join("spec/fixtures/odoo_portal/lead_show.html").read }
  subject(:attrs) { described_class.call("portal_lead_id" => "L1", "title" => "Lead", "html" => html) }

  it "maps the core contact fields" do
    expect(attrs).to include(
      company: "animeworldpak.com",
      phone: "+92 344 8431169",
      email: "husnainxbad@gmail.com",
      address: "Gujranwala",
      lead_source: "Odoo Partner Portal",
      portal_lead_id: "L1"
    )
  end

  it "uses the contact line as the customer name" do
    expect(attrs[:name]).to eq("HASSAN")
  end
end
