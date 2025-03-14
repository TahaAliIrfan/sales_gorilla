class CustomerActivity < ApplicationRecord
  belongs_to :customer
  belongs_to :user, optional: true
  
  validates :action, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
end
