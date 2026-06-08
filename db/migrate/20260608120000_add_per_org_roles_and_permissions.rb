class AddPerOrgRolesAndPermissions < ActiveRecord::Migration[7.1]
  # Phase 1 (capability) of the per-org RBAC redesign.
  # See docs/architecture/user-management-rbac.md.
  def up
    # roles become org-scoped capability bundles -----------------------------
    add_reference :roles, :organization, foreign_key: true, index: true
    add_column :roles, :permissions, :jsonb, null: false, default: []
    add_column :roles, :system, :boolean, null: false, default: false
    remove_index :roles, :key
    add_index :roles, [ :organization_id, :key ], unique: true

    # memberships gain a capability-role pointer -----------------------------
    add_reference :memberships, :role, foreign_key: { to_table: :roles }, index: true

    # Existing rows are the legacy global roles -> mark as system templates.
    execute "UPDATE roles SET system = true WHERE organization_id IS NULL"

    reset_column_information

    say_with_time "Seeding per-org system roles and backfilling membership capability roles" do
      Organization.find_each do |org|
        Role.seed_system_roles!(org)
        by_key = org.roles.system_roles.index_by(&:key)

        org.memberships.find_each do |membership|
          target = by_key[capability_key_for(membership)]
          membership.update_columns(role_id: target.id) if target
        end
      end
    end
  end

  def down
    remove_reference :memberships, :role, foreign_key: { to_table: :roles }, index: true
    # Per-org roles share keys across orgs, so they must go before the
    # globally-unique key index can be restored. Only the legacy global
    # roles (organization_id IS NULL) survive the rollback.
    execute "DELETE FROM roles WHERE organization_id IS NOT NULL"
    remove_index :roles, column: [ :organization_id, :key ]
    add_index :roles, :key, unique: true
    remove_column :roles, :system
    remove_column :roles, :permissions
    remove_reference :roles, :organization, foreign_key: true, index: true
  end

  private

  def reset_column_information
    [ Organization, Role, Membership ].each(&:reset_column_information)
  end

  # Derive a membership's per-org capability role from the user's GLOBAL
  # RoleAssignment, NOT from the legacy memberships.role string (which made
  # every non-admin an org "admin"). Preserves today's effective authorization.
  def capability_key_for(membership)
    global_keys = select_values(<<~SQL.squish)
      SELECT r.key FROM role_assignments ra
      JOIN roles r ON r.id = ra.role_id
      WHERE ra.user_id = #{membership.user_id.to_i} AND r.organization_id IS NULL
    SQL

    return "owner"   if global_keys.include?("admin")
    return "manager" if global_keys.include?("manager")
    return "member"  if global_keys.include?("associate")

    membership.role == "viewer" ? "viewer" : "member"
  end
end
