class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |t|
      t.text :content
      t.string :message_type
      t.string :status
      t.string :message_id
      t.string :direction
      t.references :user, null: true, foreign_key: true
      t.references :customer, null: true, foreign_key: true
      t.string :whatsapp_chat_id
      t.jsonb :metadata, default: {}

      t.timestamps
    end
    
    add_index :messages, :message_id
    add_index :messages, :whatsapp_chat_id
    add_index :messages, :direction
  end
end
