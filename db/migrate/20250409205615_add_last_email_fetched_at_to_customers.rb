class AddLastEmailFetchedAtToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :last_email_fetched_at, :datetime
  end
end
