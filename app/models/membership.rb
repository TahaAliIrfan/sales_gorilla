class Membership < ApplicationRecord
  ROLES = %w[owner admin member viewer].freeze

  belongs_to :user
  belongs_to :organization

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :organization_id,
                                    message: "is already a member of this organization" }

  ROLES.each do |role_name|
    define_method("#{role_name}?") { role == role_name }
  end
end
