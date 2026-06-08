class Role < ApplicationRecord
  belongs_to :organization, optional: true
  has_many :memberships, foreign_key: :role_id, dependent: :nullify
  has_many :users, through: :memberships

  validates :name, presence: true
  validates :key, presence: true, uniqueness: { scope: :organization_id }
  validates :hierarchy_level, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :permissions_are_known

  scope :system_roles, -> { where(system: true) }
  scope :custom_roles, -> { where(system: false) }

  # --- Per-organization system roles (the unified vocabulary) --------------
  SYSTEM_ROLES = [
    { key: "owner",   name: "Owner",   hierarchy_level: 100, description: "Full control including billing and deletion" },
    { key: "admin",   name: "Admin",   hierarchy_level: 90,  description: "Manage users, settings, and all data" },
    { key: "manager", name: "Manager", hierarchy_level: 50,  description: "Manage own and direct reports' data" },
    { key: "member",  name: "Member",  hierarchy_level: 10,  description: "Manage own assigned records" },
    { key: "viewer",  name: "Viewer",  hierarchy_level: 0,   description: "Read-only access" }
  ].freeze

  class << self
    # Idempotently create/refresh the 5 per-org system roles for an org.
    # Default permissions are applied only on creation, so an admin's later
    # customizations to a system role's grants are preserved across re-seeds.
    def seed_system_roles!(organization)
      SYSTEM_ROLES.each do |attrs|
        role = organization.roles.find_or_initialize_by(key: attrs[:key])
        role.name            = attrs[:name]
        role.description     = attrs[:description]
        role.hierarchy_level = attrs[:hierarchy_level]
        role.system          = true
        role.permissions     = Permission::DEFAULTS.fetch(attrs[:key], []) if role.new_record?
        role.save!
      end
    end
  end

  # Does this role grant the given capability?
  def grants?(permission_key)
    permissions.include?(permission_key.to_s)
  end

  def subordinate_roles
    base = organization_id ? Role.where(organization_id: organization_id) : Role.where(organization_id: nil)
    base.where("hierarchy_level < ?", hierarchy_level)
  end

  def outranks?(other_role)
    return false unless other_role
    hierarchy_level > other_role.hierarchy_level
  end

  private

  def permissions_are_known
    bad = Array(permissions).reject { |k| Permission.valid?(k) }
    errors.add(:permissions, "contains unknown keys: #{bad.join(', ')}") if bad.any?
  end
end
