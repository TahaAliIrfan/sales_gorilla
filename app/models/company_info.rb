# Static company details shown on invoices (screen + PDF) to establish trust.
# Single source of truth — update here if a legal entity or contact detail changes.
# Addresses sourced from the tecaudex.com footer; EIN/NTN/phone provided by ops.
class CompanyInfo
  ENTITIES = [
    {
      name: "Tecaudex Inc.",
      subtitle: "Delaware C-Corporation, USA",
      lines: ["131 Continental Dr, Suite 305", "Newark, DE 19713, USA"],
      reg_label: "EIN",
      reg_number: "32-0811384"
    },
    {
      name: "Tecaudex Private Limited",
      subtitle: "Pakistan",
      lines: ["2nd Floor, 7-B OPF, Main Boulevard", "Lahore 54770, Pakistan"],
      reg_label: "NTN",
      reg_number: "4983369-2"
    }
  ].freeze

  PHONES = [
    { label: "Phone & WhatsApp", number: "+1 (302) 206-7878" },
    { label: "Phone",            number: "+1 (656) 270-0320" }
  ].freeze

  EMAIL   = "sales@tecaudex.com"
  WEBSITE = "www.tecaudex.com"

  def self.entities
    ENTITIES
  end

  def self.phones
    PHONES
  end

  def self.email
    EMAIL
  end

  def self.website
    WEBSITE
  end
end
