class CreateOdooPortalConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :odoo_portal_connections do |t|
      t.references :organization, null: false, foreign_key: true, index: { unique: true }
      t.string :base_url, null: false, default: "https://www.odoo.com"
      t.text   :session_cookies            # encrypted JSON cookie jar
      t.string :status, null: false, default: "needs_reauth"
      t.text   :last_error
      t.datetime :last_synced_at
      t.string :watch_from
      t.string :watch_subject
      t.timestamps
    end
  end
end
