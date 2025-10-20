class AddApplicationTypesToCostEstimates < ActiveRecord::Migration[7.1]
  def change
    add_column :cost_estimates, :application_types, :text
  end
end
