class AddRepeatLeadToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :repeat_lead, :boolean, default: false, null: false
  end
end
