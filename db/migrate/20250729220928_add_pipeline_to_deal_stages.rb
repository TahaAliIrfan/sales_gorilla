class AddPipelineToDealStages < ActiveRecord::Migration[7.1]
  def change
    add_reference :deal_stages, :pipeline, null: true, foreign_key: true
    add_column :deal_stages, :active, :boolean, default: true
    
    # Create a default pipeline and assign existing stages to it
    reversible do |dir|
      dir.up do
        # Create default pipeline
        default_pipeline = Pipeline.create!(
          name: 'Default Pipeline',
          description: 'Default pipeline for existing deal stages',
          active: true
        )
        
        # Update existing deal stages to belong to the default pipeline
        DealStage.update_all(pipeline_id: default_pipeline.id)
        
        # Now make pipeline_id not null
        change_column_null :deal_stages, :pipeline_id, false
      end
      
      dir.down do
        # Remove pipeline reference
        change_column_null :deal_stages, :pipeline_id, true
      end
    end
  end
end
