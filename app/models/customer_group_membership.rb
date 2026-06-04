class CustomerGroupMembership < ApplicationRecord
  belongs_to :customer_group
  belongs_to :customer

  validates :customer_id, uniqueness: { scope: :customer_group_id }
end
