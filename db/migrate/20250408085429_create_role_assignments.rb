class CreateRoleAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :role_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.references :assigned_by, foreign_key: { to_table: :users }
      
      # For scoped roles (e.g., manager of a specific team)
      t.references :resource, polymorphic: true
      
      t.timestamps
    end
    
    add_index :role_assignments, [:user_id, :role_id, :resource_type, :resource_id], 
              unique: true, 
              name: 'index_role_assignments_on_user_role_and_resource'
  end
end
