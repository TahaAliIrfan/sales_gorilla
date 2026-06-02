class AddPhoneLookupToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :phone_line_type,         :string
    add_column :customers, :phone_carrier,           :string
    add_column :customers, :phone_lookup_checked_at, :datetime
    add_column :customers, :phone_country_code,      :string
  end
end
