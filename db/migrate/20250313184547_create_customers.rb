class CreateCustomers < ActiveRecord::Migration[7.1]
  def change
    create_table :customers do |t|
      t.string :name
      t.string :email
      t.string :phone
      t.text :address
      t.string :company

      t.timestamps
    end
  end
end
