class Deal < ApplicationRecord
  belongs_to :customer, optional: true
  belongs_to :user
  belongs_to :deal_stage
  has_one :pipeline, through: :deal_stage
  has_many :deal_activities, dependent: :destroy
  has_many :deal_recordings, dependent: :destroy
  
  validates :title, presence: { message: "is required" }
  validates :amount, presence: { message: "is required" }, 
                    numericality: { greater_than: 0, message: "must be greater than 0" }
  validates :status, presence: { message: "is required" }
  validates :customer_id, presence: { message: "is required - please select a customer" }
  validates :deal_stage_id, presence: { message: "is required - please select a deal stage" }
  validates :user_id, presence: { message: "is required - please select an owner" }
  validate :deal_stage_belongs_to_user_pipeline
  
  # Lifecycle hooks for Meta tracking
  after_save :track_meta_conversions_deal_events
  
  enum status: {
    active: 'active',
    won: 'won',
    lost: 'lost'
  }
  
  scope :assigned_to, ->(user) { where(user: user) }
  scope :by_stage, ->(stage) { where(deal_stage: stage) }
  scope :by_pipeline, ->(pipeline) { joins(:deal_stage).where(deal_stages: { pipeline: pipeline }) }
  scope :for_user_pipeline, ->(user) { 
    pipeline_ids = user.assigned_pipeline_ids
    return none if pipeline_ids.empty?
    joins(deal_stage: :pipeline).where(pipelines: { id: pipeline_ids, active: true })
  }
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

  # Track Meta Conversions API events for deal lifecycle
  def track_meta_conversions_deal_events
    return if skip_meta_tracking? || customer.nil?

    # Track deal won (Purchase event)
    if saved_change_to_status? && status == 'won'
      MetaConversionsApiWorker.perform_async(customer.id, 'purchase', { 'deal_id' => id })
    end

    # Track significant deal stage movements
    if saved_change_to_deal_stage_id? && deal_stage.present?
      stage_name = deal_stage.name.downcase
      
      # Track proposal/negotiation stages as checkout initiation
      if stage_name.include?('proposal') || stage_name.include?('negotiation') || stage_name.include?('quote')
        MetaConversionsApiWorker.perform_async(customer.id, 'initiate_checkout', { 'deal_id' => id })
      end
    end

    # Track high-value deals as view content
    if saved_change_to_amount? && amount.present? && amount > 5000
      MetaConversionsApiWorker.perform_async(customer.id, 'view_content')
    end
  end

  private

  def skip_meta_tracking?
    Rails.env.test? || 
    defined?(Rails::Console) || 
    Thread.current[:skip_meta_tracking] == true
  end

  def deal_stage_belongs_to_user_pipeline
    return if deal_stage.nil? || user.nil?
    
    # Skip validation for admins
    return if user.admin?
    
    # Check if the deal stage belongs to one of the user's assigned pipelines
    unless user.accessible_deal_stages.include?(deal_stage)
      errors.add(:deal_stage_id, "must belong to one of your assigned pipelines")
    end
  end
end
