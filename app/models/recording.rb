class Recording < ApplicationRecord
  belongs_to :user
  belongs_to :customer
  
  validates :sid, presence: true, uniqueness: true
  validates :call_sid, presence: true
  validates :duration, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  
  scope :recent, -> { order(date: :desc) }
end
