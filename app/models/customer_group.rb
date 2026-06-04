class CustomerGroup < ApplicationRecord
  acts_as_tenant(:organization)

  belongs_to :user
  has_many :customer_group_memberships, dependent: :destroy
  has_many :customers, through: :customer_group_memberships
  has_many :campaign_groups, dependent: :destroy
  has_many :campaigns, through: :campaign_groups

  validates :name, presence: true

  def add_customer(customer)
    customers << customer unless customers.include?(customer)
  end

  def remove_customer(customer)
    customers.delete(customer)
  end

  def customer_count
    customers.count
  end
end
