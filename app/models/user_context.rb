# Pundit authorization subject: a User plus their role inside the current
# organization. Pass this to policies via `pundit_user`.
#
# `user.admin?` / `user.manager?` continue to refer to the CRM's global role
# system (RoleAssignment) because every existing policy assumes that. Membership-
# scoped predicates use distinct names (`org_owner?`, `org_admin?`, `org_member?`,
# `org_viewer?`) so the two layers don't collide.
#
# Any other method falls through to the underlying User so existing helpers
# like `current_user.notifications` keep working in policies.
class UserContext
  attr_reader :user, :organization, :membership

  def initialize(user:, organization: nil, membership: nil)
    @user = user
    @organization = organization
    @membership = membership
  end

  def role
    membership&.role
  end

  # Membership-level role predicates (per-org).
  def org_owner?  = role == "owner"
  def org_admin?  = role == "admin"
  def org_member? = role == "member"
  def org_viewer? = role == "viewer"

  # Can manage organization data: everyone except read-only viewers.
  def can_write?
    membership.present? && !org_viewer?
  end

  # Can administer the organization itself: owner/admin within the org, OR a
  # global admin (so internal Tecaudex admins always see branding etc.).
  def can_administer?
    org_owner? || org_admin? || user&.admin?
  end

  # Delegate everything else (admin?, manager?, customers, notifications, …)
  # to the wrapped User, so existing policies that operate on User keep working.
  def respond_to_missing?(name, include_private = false)
    user.respond_to?(name, include_private) || super
  end

  def method_missing(name, *args, &block)
    if user.respond_to?(name)
      user.public_send(name, *args, &block)
    else
      super
    end
  end
end
