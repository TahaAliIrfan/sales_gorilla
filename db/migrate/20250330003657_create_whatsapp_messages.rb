class CreateWhatsappMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_messages do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :message_id, null: false
      t.string :remote_id
      t.text :body
      t.datetime :timestamp
      t.string :direction
      t.string :status
      t.jsonb :metadata

      t.timestamps
    end
    
    add_index :whatsapp_messages, :message_id, unique: true
    add_index :whatsapp_messages, :timestamp
    add_index :whatsapp_messages, [:customer_id, :timestamp]
  end
end
