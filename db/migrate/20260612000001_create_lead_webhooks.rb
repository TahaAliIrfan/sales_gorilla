class CreateLeadWebhooks < ActiveRecord::Migration[7.1]
  def change
    create_table :lead_webhooks do |t|
      t.string :name, null: false
      t.string :token, null: false
      t.string :lead_source, null: false
      t.string :description
      t.boolean :active, null: false, default: true
      t.integer :leads_count, null: false, default: 0
      t.datetime :last_received_at
      t.jsonb :last_payload
      t.string :last_error

      t.timestamps
    end

    add_index :lead_webhooks, :token, unique: true
  end
end
