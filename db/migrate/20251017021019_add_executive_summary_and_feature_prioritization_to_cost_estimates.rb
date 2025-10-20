class AddExecutiveSummaryAndFeaturePrioritizationToCostEstimates < ActiveRecord::Migration[7.1]
  def change
    add_column :cost_estimates, :executive_summary, :text
    add_column :cost_estimates, :feature_prioritization, :text
  end
end
