class User < ApplicationRecord
  has_many :deals
  has_many :deal_activities
  has_many :deal_recordings
  has_many :customers
  has_many :recordings

  # Admin methods
  def admin?
    is_admin
  end
  
  # Method to make a user an admin
  def make_admin!
    update(is_admin: true)
  end
  
  # Method to revoke admin privileges
  def revoke_admin!
    update(is_admin: false)
  end
end
