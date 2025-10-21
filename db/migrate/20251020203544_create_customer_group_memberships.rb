class CreateCustomerGroupMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :customer_group_memberships do |t|
      t.references :customer_group, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true

      t.timestamps
    end

    add_index :customer_group_memberships, [:customer_group_id, :customer_id], unique: true, name: 'index_customer_group_memberships_unique'
  end
end
