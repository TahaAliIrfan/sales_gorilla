class CreateMetaConversionLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :meta_conversion_logs do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :event_name, null: false
      t.boolean :success, null: false, default: false
      t.string :response_code
      t.jsonb :response_body
      t.string :error_message

      t.timestamps
    end

    add_index :meta_conversion_logs, [:customer_id, :created_at]
  end
end
