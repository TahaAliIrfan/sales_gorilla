class Deal < ApplicationRecord
  belongs_to :customer, optional: true
  belongs_to :user
  belongs_to :deal_stage
  has_many :deal_activities, dependent: :destroy
  has_many :deal_recordings, dependent: :destroy
  
  validates :title, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  
  enum status: {
    active: 'active',
    won: 'won',
    lost: 'lost'
  }
  
  scope :assigned_to, ->(user) { where(user: user) }
  scope :by_stage, ->(stage) { where(deal_stage: stage) }
  scope :active, -> { where(status: 'active') }
  scope :won, -> { where(status: 'won') }
  scope :lost, -> { where(status: 'lost') }
  
  # Log an activity for this deal
  def log_activity(user, action, details = nil)
    deal_activities.create(
      user: user,
      action: action,
      details: details
    )
  end
end
