class BackfillTaxonomiesFromConstants < ActiveRecord::Migration[7.1]
  # Default values per kind. These mirror the historical Customer constants,
  # minus "Upwork" from lead_source (per product decision). Existing customers
  # with lead_source="Upwork" keep that string in their column — they just
  # won't be able to be re-selected to it via dropdowns.
  DEFAULTS = {
    "lead_source" => %w[
      LinkedIn Email\ Marketing Social\ Media\ Platforms Website CCR
      Inbound Inbound_1 Inbound_2 Inbound_3 WA Qatar_Web_summit Web_Summit
      Leap Gitex Followup ODOO ODOO_PK
    ],
    "customer_status" => [
      "Pending", "Lead", "Contact Established", "Contact Not Established",
      "Unresponsive", "Converted", "Proposal Sent", "Not Interested",
      "Exhausted", "Invalid", "Retarget", "Exhausted_1"
    ],
    "call_status" => [
      "Pending", "Called", "Followup", "No Answer", "Wrong Number",
      "Not Interested", "Converted", "Not Applicable"
    ],
    "email_status" => [
      "Pending", "Sent", "Followup", "No Response", "Not Interested",
      "Converted", "Not Applicable"
    ],
    "whatsapp_status" => [
      "Pending", "Connected", "Followup", "No Response", "Not Interested",
      "Converted", "Not Applicable"
    ],
    "linkedin_status" => [
      "Pending", "Connected", "Followup", "No Response", "Not Interested",
      "Converted", "Not Applicable"
    ],
    "exhaust_status" => [
      "Active", "Exhausted", "Not Applicable"
    ],
    "project_type" => [
      "Mobile App", "Web App", "Chrome Extension", "Smart Watch",
      "Other"
    ]
  }.freeze

  def up
    Organization.find_each do |org|
      DEFAULTS.each do |kind, values|
        values.each_with_index do |name, idx|
          next if Taxonomy.exists?(organization_id: org.id, kind: kind, name: name)
          Taxonomy.create!(
            organization_id: org.id,
            kind: kind,
            name: name,
            position: idx + 1,
            system_default: true
          )
        end
      end
    end
  end

  def down
    Taxonomy.where(system_default: true).delete_all
  end
end
