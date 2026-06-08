class AddReportsToToMemberships < ActiveRecord::Migration[7.1]
  # Phase 2 (visibility): the per-org manager hierarchy lives on the membership
  # (Salesforce Role Hierarchy / HubSpot Teams), replacing the global
  # RoleAssignment.assigned_by manager->associate chains.
  # See docs/architecture/user-management-rbac.md.
  def up
    add_reference :memberships, :reports_to, foreign_key: { to_table: :memberships }, index: true

    # Backfill: each associate's membership reports to their manager's membership
    # in the same org, derived from the legacy associate RoleAssignment whose
    # assigned_by is the manager. Only runs while role_assignments still exists.
    return unless table_exists?(:role_assignments)

    execute(<<~SQL.squish)
      UPDATE memberships AS associate_m
      SET reports_to_id = manager_m.id
      FROM role_assignments ra
      JOIN roles r ON r.id = ra.role_id AND r.key = 'associate' AND r.organization_id IS NULL,
           memberships AS manager_m
      WHERE associate_m.user_id = ra.user_id
        AND ra.assigned_by_id IS NOT NULL
        AND ra.assigned_by_id <> ra.user_id
        AND manager_m.user_id = ra.assigned_by_id
        AND manager_m.organization_id = associate_m.organization_id
    SQL
  end

  def down
    remove_reference :memberships, :reports_to, foreign_key: { to_table: :memberships }, index: true
  end
end
