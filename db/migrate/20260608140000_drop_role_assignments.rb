class DropRoleAssignments < ActiveRecord::Migration[7.1]
  # Final retirement of the global RoleAssignment system. Capability now lives
  # on memberships.access_role and the manager hierarchy on memberships.reports_to
  # (Phase 1 + Phase 2). The legacy global roles (organization_id IS NULL) are
  # orphaned once role_assignments is gone.
  def up
    drop_table :role_assignments
    execute "DELETE FROM roles WHERE organization_id IS NULL"
  end

  def down
    create_table :role_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.bigint :assigned_by_id
      t.string :resource_type
      t.bigint :resource_id
      t.timestamps
    end
    add_index :role_assignments, :assigned_by_id
    add_index :role_assignments, [ :resource_type, :resource_id ], name: "index_role_assignments_on_resource"
    add_index :role_assignments, [ :user_id, :role_id, :resource_type, :resource_id ],
              unique: true, name: "index_role_assignments_on_user_role_and_resource"

    # Recreate the legacy global role templates (without their prior assignments).
    [
      { name: "Admin", key: "admin", description: "Full access to the system", hierarchy_level: 100 },
      { name: "Manager", key: "manager", description: "Can manage associates and view their data", hierarchy_level: 50 },
      { name: "Associate", key: "associate", description: "Basic access to manage assigned customers", hierarchy_level: 10 }
    ].each do |attrs|
      execute(<<~SQL.squish)
        INSERT INTO roles (name, key, description, hierarchy_level, organization_id, permissions, system, created_at, updated_at)
        VALUES ('#{attrs[:name]}', '#{attrs[:key]}', '#{attrs[:description]}', #{attrs[:hierarchy_level]}, NULL, '[]', true, NOW(), NOW())
      SQL
    end
  end
end
