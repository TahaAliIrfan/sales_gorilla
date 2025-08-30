class CreateAiConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_conversations do |t|
      t.string :conversation_id, null: false
      t.string :status
      t.integer :duration_seconds
      t.string :agent_id
      t.string :call_from
      t.string :call_to
      t.datetime :conversation_date
      t.jsonb :transcript
      t.jsonb :raw_data
      t.references :user, null: true, foreign_key: true
      t.references :customer, null: true, foreign_key: true

      t.timestamps
    end

    add_index :ai_conversations, :conversation_id, unique: true
    add_index :ai_conversations, :status
    add_index :ai_conversations, :conversation_date
  end
end
