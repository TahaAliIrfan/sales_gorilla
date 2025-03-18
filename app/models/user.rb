class User < ApplicationRecord
  has_many :deals
  has_many :deal_activities
  has_many :deal_recordings
  has_many :customers
  has_many :recordings
  has_many :tasks, dependent: :nullify
  
  # Validate phone number format
  validates :phone_number, format: { with: /\A\+\d{6,15}\z/, message: "must be a valid phone number with country code (e.g. +923001234567)", allow_blank: true }
  
  # Check if phone number is set
  def phone_number_set?
    phone_number.present?
  end

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
  
  # Task methods
  def pending_tasks
    tasks.pending
  end
  
  def tasks_for_today
    tasks.for_today
  end
  
  def overdue_tasks
    tasks.overdue
  end
end
