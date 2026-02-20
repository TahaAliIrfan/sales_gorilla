class AddUtmFieldsToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :utm_campaign, :string
    add_column :customers, :utm_term, :string
  end
end
