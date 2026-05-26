class AddAiNarrativeToOdooProposals < ActiveRecord::Migration[7.1]
  def change
    add_column :odoo_proposals, :industry, :string
    add_column :odoo_proposals, :company_size, :string
    add_column :odoo_proposals, :pain_points, :jsonb, default: []

    add_column :odoo_proposals, :claude_summary, :text
    add_column :odoo_proposals, :claude_rationale, :text
    add_column :odoo_proposals, :claude_module_justifications, :jsonb, default: {}
    add_column :odoo_proposals, :claude_next_steps, :text
    add_column :odoo_proposals, :narrative_generated_at, :datetime
  end
end
