class AddStatusAndProposedFeaturesToCostEstimates < ActiveRecord::Migration[7.1]
  def change
    add_column :cost_estimates, :status, :string, default: 'init'
    add_column :cost_estimates, :proposed_features, :text
    add_index :cost_estimates, :status
  end
end
