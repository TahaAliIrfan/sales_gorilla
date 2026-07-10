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
  # Keep the customer's lead score in sync as deals move through the pipeline.
  after_commit :rescore_customer, on: [:create, :update, :destroy]
  
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
  
  # Recompute the customer's rule-based lead score (cheap, no AI) after the deal
  # changes, so pipeline progress is reflected in the score.
  def rescore_customer
    customer&.recompute_lead_score!
  end

  # Log an activity for this deal
  def log_activity(user, action, details = nil)
    deal_activities.create(
      user: user,
      action: action,
      details: details
    )
  end

  # Track Meta Conversions API events for deal lifecycle.
  # Only fires when the associated customer is an inbound Meta lead.
  def track_meta_conversions_deal_events
    return if customer.nil? || !customer.meta_eligible?

    service = MetaConversionsApiService.new
    return unless service.credentials_configured?

    action_source = customer.meta_action_source


    # Schedule — fires once when the deal is first created
    if saved_change_to_id?
      service.send_form_lead_event(customer, 'Schedule', nil, action_source)
    end

    # Purchase — fires when the deal is marked as won
    if saved_change_to_status? && status == 'won'
      service.send_form_lead_event(customer, 'Purchase', amount, action_source)
    end
  end

  def deal_stage_belongs_to_user_pipeline
    return if deal_stage.nil? || user.nil?

    # Skip validation for admins
    return if user.admin?

    # Skip validation if only status/closing_date changed (not deal_stage)
    return if persisted? && !deal_stage_id_changed?

    # Check if the deal stage belongs to one of the user's assigned pipelines
    unless user.accessible_deal_stages.include?(deal_stage)
      errors.add(:deal_stage_id, "must belong to one of your assigned pipelines")
    end
  end
end
