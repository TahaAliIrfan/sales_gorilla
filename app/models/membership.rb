class Membership < ApplicationRecord
  # Legacy org-level string roles. Kept during the transition (still drives the
  # org_owner?/org_admin? predicates in UserContext). The capability source of
  # truth is now #access_role; this column is retired in Phase 2.
  ROLES = %w[owner admin member viewer].freeze

  belongs_to :user
  belongs_to :organization
  # Per-organization capability role (Phase 1). Named access_role rather than
  # :role so the existing `role` string accessor keeps working unchanged.
  belongs_to :access_role, class_name: "Role", foreign_key: :role_id, optional: true

  # Per-organization manager hierarchy (Phase 2): who this member reports to,
  # and the memberships that report to them. Replaces the global
  # RoleAssignment.assigned_by chains.
  belongs_to :reports_to, class_name: "Membership", optional: true
  has_many :direct_reports, class_name: "Membership", foreign_key: :reports_to_id, dependent: :nullify

  validates :role, presence: true, inclusion: { in: ROLES }
  validate :reports_to_same_organization
  validates :user_id, uniqueness: { scope: :organization_id,
                                    message: "is already a member of this organization" }

  before_validation :assign_default_access_role, on: :create

  ROLES.each do |role_name|
    define_method("#{role_name}?") { role == role_name }
  end

  # Capability check against the assigned role's granted permissions.
  def can?(permission_key)
    access_role&.grants?(permission_key) || false
  end

  def role_key
    access_role&.key
  end

  private

  # New memberships map their string role to the org's like-named system role.
  def assign_default_access_role
    return if access_role || organization.nil?
    self.access_role = organization.roles.system_roles.find_by(key: role)
  end

  def reports_to_same_organization
    return if reports_to.nil? || reports_to.organization_id == organization_id
    errors.add(:reports_to, "must be in the same organization")
  end
end
