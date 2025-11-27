class AddCallAttemptTrackingToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :total_call_attempts, :integer, default: 0, null: false
    add_column :customers, :successful_call_attempts, :integer, default: 0, null: false
    add_column :customers, :last_call_attempt_at, :datetime
    add_column :customers, :last_successful_call_at, :datetime
  end
end
