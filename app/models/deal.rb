class Deal < ApplicationRecord
  belongs_to :customer, optional: true
  belongs_to :user
  belongs_to :deal_stage
  has_many :deal_activities, dependent: :destroy
  has_many :deal_recordings, dependent: :destroy
  
  validates :title, presence: { message: "is required" }
  validates :amount, presence: { message: "is required" }, 
                    numericality: { greater_than: 0, message: "must be greater than 0" }
  validates :customer_id, presence: { message: "is required - please select a customer" }
  validates :deal_stage_id, presence: { message: "is required - please select a deal stage" }
  validates :user_id, presence: { message: "is required - please select an owner" }
  
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
