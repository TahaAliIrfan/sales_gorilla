class AddNotesToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :notes, :text
  end
end
