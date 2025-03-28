class CreateAiAnalyses < ActiveRecord::Migration[7.1]
  def change
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
end
