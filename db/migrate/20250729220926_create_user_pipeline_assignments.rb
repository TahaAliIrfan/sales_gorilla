class CreateUserPipelineAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :user_pipeline_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :pipeline, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :user_pipeline_assignments, [:user_id, :pipeline_id], unique: true
  end
end
