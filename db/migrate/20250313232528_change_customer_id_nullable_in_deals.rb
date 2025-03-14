class ChangeCustomerIdNullableInDeals < ActiveRecord::Migration[7.1]
  def change
    change_column_null :deals, :customer_id, true
  end
end
