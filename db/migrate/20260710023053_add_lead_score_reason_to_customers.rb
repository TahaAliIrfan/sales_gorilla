class AddLeadScoreReasonToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :lead_score_reason, :text
  end
end
