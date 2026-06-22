class CreatePartnerPortalLeads < ActiveRecord::Migration[7.1]
  def change
    create_table :partner_portal_leads do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :customer, null: true, foreign_key: true
      t.string  :portal_lead_id, null: false
      t.string  :status, null: false, default: "received"
      t.jsonb   :raw_payload, null: false, default: {}
      t.text    :error_message
      t.datetime :processed_at
      t.timestamps
      t.index [:organization_id, :portal_lead_id], unique: true, name: "idx_portal_leads_on_org_and_portal_id"
    end
  end
end
