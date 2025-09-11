class AddDesignAndCustomerToCostEstimates < ActiveRecord::Migration[7.1]
  def change
    add_column :cost_estimates, :include_design, :boolean, default: false, null: false
    add_column :cost_estimates, :customer_id, :integer, null: true
    add_column :cost_estimates, :customer_name, :string, null: true
    
    add_index :cost_estimates, :customer_id
    add_foreign_key :cost_estimates, :customers, column: :customer_id, on_delete: :nullify
  end
end
