# Capability catalog for per-organization RBAC.
#
# Permissions are a fixed set of capability keys defined in code (like Odoo's
# ACL or a Salesforce permission set). A Role grants a subset of these, stored
# as a string array in Role#permissions. New code authorizes via
# `pundit_user.can?("customers.export")` rather than `user.admin?`.
#
# See docs/architecture/user-management-rbac.md.
module Permission
  # key => human label, grouped by category for the admin UI.
  CATALOG = {
    "Organization" => {
      "org.administer"     => "Administer organization settings & branding",
      "org.manage_billing" => "Manage billing & subscription",
      "org.delete"         => "Delete the organization"
    },
    "Users & Roles" => {
      "users.view"   => "View users",
      "users.invite" => "Invite users",
      "users.manage" => "Edit & deactivate users",
      "roles.manage" => "Create & edit roles"
    },
    "Customers" => {
      "customers.view_all"  => "View all customers in the org",
      "customers.view_team" => "View team members' customers",
      "customers.export"    => "Export customers",
      "customers.bulk_edit" => "Bulk edit / assign customers"
    },
    "Deals" => {
      "deals.view_all" => "View all deals in the org",
      "deals.assign"   => "Assign deals to users"
    },
    "Recordings" => {
      "recordings.view_all" => "View all call recordings"
    },
    "Settings" => {
      "settings.manage"  => "Manage CRM settings",
      "templates.manage" => "Manage message templates"
    }
  }.freeze

  ALL_KEYS = CATALOG.values.flat_map(&:keys).freeze

  # Default grants for each seeded system role. member/viewer get no elevated
  # capabilities — their access to their own records is record-scoped
  # (ownership / tenancy), not a capability grant. The manager→reports
  # visibility rollup is the Phase 2 (visibility) axis.
  DEFAULTS = {
    "owner"   => ALL_KEYS,
    "admin"   => ALL_KEYS - %w[org.delete org.manage_billing],
    "manager" => %w[
      users.view
      customers.view_all customers.view_team customers.export customers.bulk_edit
      deals.view_all deals.assign
      recordings.view_all
      templates.manage
    ].freeze,
    "member"  => [].freeze,
    "viewer"  => [].freeze
  }.freeze

  def self.valid?(key)
    ALL_KEYS.include?(key.to_s)
  end

  def self.label(key)
    CATALOG.each_value { |group| return group[key.to_s] if group.key?(key.to_s) }
    nil
  end
end
