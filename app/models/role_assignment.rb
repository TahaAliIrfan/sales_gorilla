class RoleAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :role
  belongs_to :assigned_by, class_name: "User", optional: true
  belongs_to :resource, polymorphic: true, optional: true

  validates :user_id, uniqueness: { scope: [ :role_id, :resource_type, :resource_id ],
                                   message: "already has this role assignment" }

  # Validate that the assigner has appropriate permissions
  validate :assigner_has_permission, if: -> { assigned_by.present? }

  # Scopes
  scope :global, -> { where(resource_id: nil, resource_type: nil) }
  scope :for_resource, ->(resource) { where(resource: resource) }

  private

  def assigner_has_permission
    # Check if the assigner has admin role or has a higher role than the one being assigned
    unless assigned_by.admin? || (assigned_by.highest_role && assigned_by.highest_role.outranks?(role))
      errors.add(:assigned_by, "doesn't have permission to assign this role")
    end
  end
end
