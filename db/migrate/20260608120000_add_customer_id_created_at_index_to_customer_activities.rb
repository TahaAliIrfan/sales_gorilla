class AddCustomerIdCreatedAtIndexToCustomerActivities < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    # Supports the correlated NOT EXISTS subquery in UserDashboardController#index
    # (customers_needing_attention) over the ~43M-row customer_activities table.
    # Built CONCURRENTLY to avoid locking writes on a large table.
    add_index :customer_activities, [ :customer_id, :created_at ],
              algorithm: :concurrently,
              if_not_exists: true,
              name: "index_customer_activities_on_customer_id_and_created_at"
  end
end
