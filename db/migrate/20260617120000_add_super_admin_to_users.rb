class AddSuperAdminToUsers < ActiveRecord::Migration[7.1]
  def change
    # Platform-level super admin (the owner of the app itself, NOT an org owner).
    # Gates the cross-org /admin panel. Distinct from the per-org admin?/owner?
    # capability checks which are scoped to a single organization.
    add_column :users, :super_admin, :boolean, default: false, null: false
    add_index :users, :super_admin, where: "super_admin"
  end
end
