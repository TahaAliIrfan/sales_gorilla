class AddAiFieldsToCostEstimates < ActiveRecord::Migration[7.1]
  def change
    add_column :cost_estimates, :project_name, :string
    add_column :cost_estimates, :project_overview, :text
    add_column :cost_estimates, :technical_information_summary, :text
    add_column :cost_estimates, :estimated_timeline_weeks, :integer
    add_column :cost_estimates, :team_composition, :string
    add_column :cost_estimates, :development_methodology, :string
    add_column :cost_estimates, :key_technology_areas, :string
  end
end
