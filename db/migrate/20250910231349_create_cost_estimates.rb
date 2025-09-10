class CreateCostEstimates < ActiveRecord::Migration[7.1]
  def change
    create_table :cost_estimates do |t|
      t.string :app_type
      t.text :description
      t.text :features_json
      t.integer :total_hours
      t.decimal :hourly_rate
      t.decimal :total_cost
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
