class CreateCustomerAiChatMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :customer_ai_chat_messages do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false

      t.timestamps
    end

    add_index :customer_ai_chat_messages, [:customer_id, :created_at]
  end
end
