class Deal < ApplicationRecord
  acts_as_tenant(:organization)

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
    active: "active",
    won: "won",
    lost: "lost"
  }

  scope :assigned_to, ->(user) { where(user: user) }
  scope :by_stage, ->(stage) { where(deal_stage: stage) }
  scope :by_pipeline, ->(pipeline) { joins(:deal_stage).where(deal_stages: { pipeline: pipeline }) }
  scope :for_user_pipeline, ->(user) {
    pipeline_ids = user.assigned_pipeline_ids
    return none if pipeline_ids.empty?
    joins(deal_stage: :pipeline).where(pipelines: { id: pipeline_ids, active: true })
  }
  scope :active, -> { where(status: "active") }
  scope :won, -> { where(status: "won") }
  scope :lost, -> { where(status: "lost") }

  # Log an activity for this deal
  def log_activity(user, action, details = nil)
    deal_activities.create(
      user: user,
      action: action,
      details: details
    )
  end

  # Fires the Meta event mapped to this deal's current stage (configured in
  # Settings > Features > Meta Conversions API → deal stage mappings). Runs on
  # creation OR on stage change; admins map each pipeline stage to whichever
  # standard event makes sense (Schedule, SubmitApplication, Purchase, etc.).
  #
  # No dedup at the model level: moving a deal back-and-forth between stages
  # will fire repeat events. The intent is that pipeline stages flow forward.
  def track_meta_conversions_deal_events
    return if customer.nil? || !customer.meta_eligible?
    return unless saved_change_to_deal_stage_id? || saved_change_to_id?

    service = MetaConversionsApiService.new(organization: customer.organization)
    return unless service.credentials_configured?

    event_name = service.event_for_deal_stage(deal_stage_id)
    return if event_name.blank?
    return unless service.event_enabled?(event_name)

    amount_arg = (event_name == "Purchase") ? amount : nil
    service.send_form_lead_event(customer, event_name, amount_arg, customer.meta_action_source)
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
