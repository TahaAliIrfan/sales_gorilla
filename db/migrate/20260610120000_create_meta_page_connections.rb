class CreateMetaPageConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :meta_page_connections do |t|
      t.references :organization, null: false, foreign_key: true
      # Facebook Page id is the webhook routing key (payload carries page_id but
      # not org). NOT secret, so it's a plain indexed column we can look up by.
      t.string :page_id, null: false
      t.string :page_name
      # Long-lived Page access token used to fetch each lead's field_data.
      # Encrypted at rest like OrganizationFeature#settings.
      t.text   :page_access_token
      # Per-page lead source mapping (decision: per-page, default "Inbound").
      t.string :lead_source, null: false, default: "Inbound"
      t.string :status, null: false, default: "active" # active | revoked | error
      t.text   :last_error
      t.datetime :subscribed_at

      t.timestamps
    end

    # One org owns a given page; also the fast webhook lookup key.
    add_index :meta_page_connections, :page_id, unique: true
    add_index :meta_page_connections, %i[organization_id status]
  end
end
