class RemoveAiCallingTables < ActiveRecord::Migration[7.1]
  def up
    drop_table :ai_conversations if table_exists?(:ai_conversations)
    drop_table :ai_analyses if table_exists?(:ai_analyses)
  end

  def down
    # Recreate ai_conversations table
    create_table :ai_conversations do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :conversation_id, null: false, index: { unique: true }
      t.string :status
      t.datetime :conversation_date, index: true
      t.text :transcript
      t.string :recording_url
      t.integer :duration_seconds
      t.text :metadata
      t.text :summary
      t.decimal :cost, precision: 10, scale: 4

      t.timestamps
    end
    
    add_index :ai_conversations, :status
    add_index :ai_conversations, :conversation_date

    # Recreate ai_analyses table
    create_table :ai_analyses do |t|
      t.references :recording, null: false, foreign_key: true
      t.text :transcript
      t.text :summary
      t.text :action_items
      t.decimal :sentiment_score
      t.string :analysis_status

      t.timestamps
    end
  end
end
