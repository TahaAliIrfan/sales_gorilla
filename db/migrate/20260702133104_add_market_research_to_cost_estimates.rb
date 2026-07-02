class AddMarketResearchToCostEstimates < ActiveRecord::Migration[7.1]
  def change
    add_column :cost_estimates, :market_research, :text
  end
end
