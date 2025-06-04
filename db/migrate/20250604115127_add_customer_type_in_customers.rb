class AddCustomerTypeInCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :customer_type, :string, default: 'Standard'
  end
end
