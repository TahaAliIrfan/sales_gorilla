require "rails_helper"

# Fixture is a REAL odoo.com partner-portal lead detail page (captured live),
# so this spec proves the parser works against the actual portal markup.
RSpec.describe OdooPortal::LeadParser do
  let(:html) { Rails.root.join("spec/fixtures/odoo_portal/lead_show.html").read }

  context "parsing the real detail page (no list fields)" do
    subject(:attrs) { described_class.call("portal_lead_id" => "40815402", "html" => html) }

    it "maps the customer's company, phone and email from the Customer row microdata" do
      expect(attrs).to include(
        company: "Trendy Wibes",
        phone: "+92 330 1071782",
        email: "d11157825@gmail.com",
        address: "Lahore",
        lead_source: "Odoo Partner Portal",
        portal_lead_id: "40815402"
      )
    end

    it "extracts the contact name from the lead title" do
      expect(attrs[:name]).to eq("Danish Nazir")
    end

    it "does not leak the Assigned Partner (Tecaudex) email/phone" do
      expect(attrs[:email]).not_to eq("tecaudex@gmail.com")
      expect(attrs[:phone]).not_to eq("+923237399596")
    end
  end

  context "when the list page already supplied structured columns" do
    subject(:attrs) do
      described_class.call(
        "portal_lead_id" => "40815402", "html" => html,
        "contact_name" => "Danish Nazir", "email" => "d11157825@gmail.com", "phone" => "+92 330 1071782"
      )
    end

    it "prefers the list-provided fields" do
      expect(attrs).to include(name: "Danish Nazir", email: "d11157825@gmail.com", phone: "+92 330 1071782")
    end
  end
end
