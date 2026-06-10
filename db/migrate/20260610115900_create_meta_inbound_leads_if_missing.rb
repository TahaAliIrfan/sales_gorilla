# Reconciles schema drift: `meta_inbound_leads` is present in schema.rb (and in
# dev/local) but its physical table is MISSING on the revamp production DB while
# its original creating migration is already recorded in schema_migrations — so
# a normal `db:migrate` will not recreate it. This guarded migration creates the
# table only when absent, matching the schema.rb definition (columns, indexes,
# FKs). It is a no-op anywhere the table already exists.
class CreateMetaInboundLeadsIfMissing < ActiveRecord::Migration[7.1]
  def up
    return if table_exists?(:meta_inbound_leads)

    create_table :meta_inbound_leads do |t|
      t.bigint   :organization_id, null: false
      t.bigint   :customer_id
      t.string   :leadgen_id, null: false
      t.string   :page_id
      t.string   :form_id
      t.string   :ad_id
      t.string   :adset_id
      t.string   :campaign_id
      t.string   :status, null: false, default: "received"
      t.text     :error_message
      t.jsonb    :webhook_payload
      t.jsonb    :lead_data
      t.datetime :received_at, null: false
      t.datetime :processed_at
      t.timestamps
    end

    add_index :meta_inbound_leads, :customer_id
    add_index :meta_inbound_leads, :form_id
    add_index :meta_inbound_leads, %i[organization_id leadgen_id], unique: true
    add_index :meta_inbound_leads, :organization_id
    add_index :meta_inbound_leads, :status

    add_foreign_key :meta_inbound_leads, :organizations
    add_foreign_key :meta_inbound_leads, :customers
  end

  def down
    # Intentionally no-op: the table predates this reconcile migration on
    # environments that already have it, so we never drop it here.
  end
end
