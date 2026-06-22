class AddIntelligenceFieldsToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :enrichment_summary, :text
    add_column :customers, :industry, :string
    add_column :customers, :legitimacy_score, :integer
    add_column :customers, :lead_is_junk, :boolean
    add_column :customers, :enriched_at, :datetime
    add_column :customers, :call_script, :text
    add_column :customers, :call_script_generated_at, :datetime
  end
end
