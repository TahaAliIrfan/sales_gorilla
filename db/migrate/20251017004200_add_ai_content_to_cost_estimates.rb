class AddAiContentToCostEstimates < ActiveRecord::Migration[7.1]
  def change
    add_column :cost_estimates, :app_name, :string
    add_column :cost_estimates, :similar_apps, :text
    add_column :cost_estimates, :mockups_html, :text
    add_column :cost_estimates, :pdf_url, :string
  end
end
