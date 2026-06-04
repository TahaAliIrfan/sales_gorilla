module SettingsHelper
  # Branding + team + features tabs are owner/admin-only, mirroring
  # OrganizationPolicy#edit_branding? (→ UserContext#can_administer?). Uses
  # pundit_user so both org membership (owner/admin) and global admins count.
  # Shared by the settings workspace and the features page so both gate the same
  # way.
  def admin_tabs?
    return false unless current_user

    policy(current_organization || Organization.new).edit_branding?
  end

  # DS badge modifier for a role key (admin → danger, manager → info,
  # associate → neutral), mirroring view-settings.jsx ROLE_BADGE.
  ROLE_BADGES = {
    "admin"     => "rl-badge--danger",
    "manager"   => "rl-badge--info",
    "associate" => "rl-badge--neutral"
  }.freeze

  def settings_role_badge(role_key)
    ROLE_BADGES.fetch(role_key.to_s, "rl-badge--neutral")
  end
end
