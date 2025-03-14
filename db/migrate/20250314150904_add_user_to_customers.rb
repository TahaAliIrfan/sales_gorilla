class AddUserToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_reference :customers, :user, null: true, foreign_key: true
  end
end
