require "nokogiri"

module OdooPortal
  # Pure transform: a scraped lead payload -> Customer attribute hash. No DB, no
  # browser. Selector-light + regex fallbacks so portal markup tweaks don't break
  # ingestion. Field extraction is label-driven ("Phone: ...").
  class LeadParser
    LABELS = {
      name: /Contact:\s*(.+)/i,
      company: /Customer:\s*(.+)/i,
      phone: /Phone:\s*(.+)/i,
      email: /Email:\s*(.+)/i,
      address: /Address:\s*(.+)/i,
      status: /Stage:\s*(.+)/i
    }.freeze

    def self.call(payload) = new(payload).call

    def initialize(payload)
      @payload = payload
      @text = Nokogiri::HTML(payload["html"].to_s).text
    end

    def call
      LABELS.transform_values { |re| @text[re, 1]&.strip }.merge(
        portal_lead_id: @payload["portal_lead_id"],
        lead_source: "Odoo Partner Portal"
      ).compact
    end
  end
end
