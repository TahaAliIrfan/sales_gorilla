class AddFieldsToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :lead_source, :string, default: ''
    add_column :customers, :country_code, :string
    add_column :customers, :linkedin_url, :string
    add_column :customers, :ccr_link, :string
    add_column :customers, :project_estimated_cost, :decimal, precision: 10, scale: 2
    add_column :customers, :project_type, :string, default: 'Not Applicable'
    add_column :customers, :idea_description, :text
    add_column :customers, :status, :string, default: 'Pending'
    add_column :customers, :call_status, :string, default: 'Pending'
    add_column :customers, :email_status, :string, default: 'Pending'
    add_column :customers, :whatsapp_status, :string, default: 'Pending'
    add_column :customers, :linkedin_status, :string, default: 'Pending'
    add_column :customers, :upwork_profile, :string, default: 'Not Applicable'
    add_column :customers, :exhaust_status, :string, default: 'Not Applicable'
    add_column :customers, :exhaust_date, :datetime
    add_column :customers, :country, :string
  end
end
