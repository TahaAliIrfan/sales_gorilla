class CreateUserKpiRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :user_kpi_records do |t|
      t.references :user, null: false, foreign_key: true
      t.date :record_date, null: false
      t.integer :calls_attempted, default: 0, null: false
      t.integer :connected_calls, default: 0, null: false
      t.integer :whatsapp_messages_sent, default: 0, null: false
      t.integer :emails_sent, default: 0, null: false

      t.timestamps
    end

    add_index :user_kpi_records, [:user_id, :record_date], unique: true
    add_index :user_kpi_records, :record_date
  end
end
