class Pipeline < ApplicationRecord
  has_many :deal_stages, dependent: :destroy
  has_many :deals, through: :deal_stages
  has_many :user_pipeline_assignments, dependent: :destroy
  has_many :users, through: :user_pipeline_assignments
  
  validates :name, presence: true, uniqueness: true
  
  scope :active, -> { where(active: true) }
  
  def stages
    deal_stages.order(:position)
  end
  
  def active_stages
    deal_stages.where(active: true).order(:position)
  end
  
  def deals_count
    deals.count
  end
  
  def active_deals_count
    deals.active.count
  end
end