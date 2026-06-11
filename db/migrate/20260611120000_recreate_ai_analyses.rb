class RecreateAiAnalyses < ActiveRecord::Migration[7.1]
  # The ai_analyses table and its model were lost (model file deleted, table
  # dropped) even though CreateAiAnalyses (20250328163526) is recorded as run.
  # Recreate the table from its original definition. Guarded so it is a no-op
  # on any environment where the table still exists.
  def up
    return if table_exists?(:ai_analyses)

    create_table :ai_analyses do |t|
      t.references :recording, null: false, foreign_key: true
      t.text :summary
      t.integer :interest_score
      t.text :improvement_points
      t.text :next_steps
      t.text :followup_message
      t.text :followup_email

      t.timestamps
    end
  end

  def down
    drop_table :ai_analyses if table_exists?(:ai_analyses)
  end
end
