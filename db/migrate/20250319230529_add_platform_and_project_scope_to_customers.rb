class AddPlatformAndProjectScopeToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :platform, :string, default: 'Not Applicable'
    add_column :customers, :project_scope, :string, default: 'Not Applicable'
  end
end
