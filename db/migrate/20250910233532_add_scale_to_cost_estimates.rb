class AddScaleToCostEstimates < ActiveRecord::Migration[7.1]
  def change
    add_column :cost_estimates, :scale, :string
  end
end
