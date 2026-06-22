class AddDemoFieldsToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :demo_url, :string
    add_column :customers, :demo_db, :string
    add_column :customers, :demo_login, :string
    add_column :customers, :demo_password, :text       # encrypted in the model
    add_column :customers, :demo_status, :string
    add_column :customers, :demo_built_at, :datetime
  end
end
