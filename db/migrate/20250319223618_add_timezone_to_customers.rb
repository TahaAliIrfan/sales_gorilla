class AddTimezoneToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :timezone, :string
  end
end
