require "nokogiri"

module OdooPortal
  # Pure transform: a scraped lead payload -> Customer attribute hash. No DB, no
  # browser.
  #
  # The real odoo.com partner-portal lead page uses schema.org microdata. The
  # contact's company/phone/email live as itemprops INSIDE the "Customer:" row's
  # <address> (the page also repeats telephone/email itemprops for the Assigned
  # Partner — Tecaudex — so we MUST scope to the Customer row, not grab globally).
  # The contact name comes from the title: "Lead - <Name> (<Company>) Registration".
  #
  # Where the list page already provided structured columns (contact_name, email,
  # phone, company), we prefer those and fall back to parsing the detail HTML.
  class LeadParser
    def self.call(payload) = new(payload).call

    def initialize(payload)
      @payload = payload
      @doc = Nokogiri::HTML(payload["html"].to_s)
    end

    def call
      {
        name: name,
        company: company,
        email: email,
        phone: phone,
        address: address,
        lead_source: "Odoo Partner Portal",
        portal_lead_id: @payload["portal_lead_id"]
      }.compact
    end

    private

    # "Lead - Danish Nazir (Trendy Wibes) Registration"
    def title
      @title ||= (@payload["title"].presence || @doc.at_css("h4")&.text.to_s).gsub(/\s+/, " ").strip
    end

    def name
      @payload["contact_name"].presence ||
        title[/Lead\s*-\s*(.+?)\s*\(/i, 1]&.strip ||
        title[/-\s*(.+?)\s*\(/, 1]&.strip
    end

    # The <address> inside the row whose <th> is "Customer:".
    def customer_address
      @customer_address ||= begin
        row = @doc.css("table tr").find { |tr| tr.at_css("th")&.text.to_s.strip.start_with?("Customer:") }
        row&.at_css("address")
      end
    end

    def company
      @payload["company"].presence ||
        customer_address&.at_css('[itemprop="name"]')&.text&.strip ||
        title[/\((.+?)\)/, 1]&.strip
    end

    def phone
      @payload["phone"].presence || customer_address&.at_css('[itemprop="telephone"]')&.text&.strip
    end

    def email
      @payload["email"].presence || customer_address&.at_css('[itemprop="email"]')&.text&.strip
    end

    def address
      row = @doc.css("table tr").find { |tr| tr.at_css("th")&.text.to_s.strip.start_with?("Address:") }
      row&.at_css("td")&.text&.gsub(/\s+/, " ")&.strip.presence
    end
  end
end
