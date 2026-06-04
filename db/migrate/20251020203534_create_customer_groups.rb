class CreateCustomerGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :customer_groups do |t|
      t.string :name, null: false
      t.text :description
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :customer_groups, [:user_id, :name]
  end
end
