class AddLeadScoreToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :lead_score, :integer
    add_column :customers, :geographic_score, :integer
    add_column :customers, :description_score, :integer
    add_column :customers, :lead_score_updated_at, :datetime
  end
end
