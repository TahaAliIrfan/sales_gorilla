class AddPreferredCallingTimeToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :preferred_calling_time, :string, default: ''
  end
end
