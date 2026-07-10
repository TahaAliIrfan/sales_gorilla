class AddDefaultCallerIdToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :default_caller_id, :string
  end
end
