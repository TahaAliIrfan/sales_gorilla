class AddPortalFieldsToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :portal_lead_id, :string
    add_column :customers, :portal_last_pushed_at, :datetime
    add_index  :customers, [:organization_id, :portal_lead_id]
  end
end
