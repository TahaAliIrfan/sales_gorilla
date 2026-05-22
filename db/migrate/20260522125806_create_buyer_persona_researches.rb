class CreateBuyerPersonaResearches < ActiveRecord::Migration[7.1]
  def change
    create_table :buyer_persona_researches do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :status
      t.text :professional_background
      t.text :industry_analysis
      t.text :pain_points
      t.text :budget_indicators
      t.text :communication_style
      t.text :recommended_approach
      t.text :key_insights
      t.text :persona_summary
      t.integer :confidence_score
      t.jsonb :raw_response
      t.datetime :researched_at

      t.timestamps
    end
  end
end
