class CreateProposalChats < ActiveRecord::Migration[7.1]
  def change
    create_table :proposal_chats do |t|
      t.references :user, null: false, foreign_key: true
      t.references :customer, null: true, foreign_key: true # set when a customer is imported
      t.string :title
      t.timestamps
    end
    add_index :proposal_chats, [:user_id, :updated_at]

    create_table :proposal_chat_messages do |t|
      t.references :proposal_chat, null: false, foreign_key: true
      t.string :role, null: false          # user | assistant | context
      t.text :content, null: false
      t.timestamps
    end
    add_index :proposal_chat_messages, [:proposal_chat_id, :created_at]
  end
end
