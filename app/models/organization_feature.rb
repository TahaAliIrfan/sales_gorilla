class OrganizationFeature < ApplicationRecord
  KEYS = %w[calling transcription meta_conversions].freeze

  PROVIDERS = {
    "calling" => %w[twilio].freeze,
    "transcription" => %w[deepgram].freeze,
    "meta_conversions" => %w[meta].freeze
  }.freeze

  # Defaults applied at backfill time for a fresh meta_conversions row. Mirror
  # the previously-hardcoded behavior so per-org config is opt-in, not a regression.
  META_DEFAULT_EVENTS = %w[Lead Contact Schedule Purchase].freeze
  META_DEFAULT_ELIGIBLE_SOURCES = %w[Inbound Inbound_1 Inbound_2 Inbound_3 CCR Website].freeze

  # Standard Meta event names admins can map statuses/stages to. Subset of the
  # Meta CAPI standard event catalog. Customs can be added by editing the
  # mapping directly; the UI exposes this list as the dropdown.
  META_AVAILABLE_EVENTS = %w[
    Lead Contact Schedule SubmitApplication CompleteRegistration
    StartTrial Subscribe AddToCart InitiateCheckout AddPaymentInfo Purchase
  ].freeze

  # Valid action_source values from Meta CAPI. Picking the right one is
  # critical for attribution: lead-ads webhooks should be `system_generated`,
  # click-to-call ads should be `phone_call`, etc.
  META_ACTION_SOURCES = %w[
    system_generated website phone_call email chat business_messaging
    app physical_store other
  ].freeze

  # Default status->event mapping for Customer model. Keys must be Customer
  # status values; nil/missing means "don't fire any event for this status".
  META_DEFAULT_CUSTOMER_STATUS_MAPPINGS = {
    "Pending"             => "Lead",
    "Contact Established" => "Contact"
  }.freeze

  # Default source->action_source mapping. Reflects the R&D in docs/architecture:
  # Lead Ads (Inbound*) → system_generated, CCR → phone_call (not website!),
  # Website → website. `require_lead_id` is true for Lead Ads sources where
  # meta_lead_id is the canonical match key.
  META_DEFAULT_SOURCE_ACTION_SOURCES = {
    "Inbound"   => { "action_source" => "system_generated", "require_lead_id" => true },
    "Inbound_1" => { "action_source" => "system_generated", "require_lead_id" => true },
    "Inbound_2" => { "action_source" => "system_generated", "require_lead_id" => true },
    "Inbound_3" => { "action_source" => "system_generated", "require_lead_id" => true },
    "CCR"       => { "action_source" => "phone_call",       "require_lead_id" => false },
    "Website"   => { "action_source" => "website",          "require_lead_id" => false },
    "WA"        => { "action_source" => "business_messaging", "require_lead_id" => false }
  }.freeze

  belongs_to :organization
  acts_as_tenant :organization

  serialize :settings, coder: JSON, type: Hash
  encrypts :settings

  validates :key, presence: true, inclusion: { in: KEYS }
  validates :key, uniqueness: { scope: :organization_id }
  validate :provider_is_known

  def settings_hash
    settings.presence || {}
  end

  def settings_for(*path)
    path.reduce(settings_hash) { |acc, k| acc.is_a?(Hash) ? acc[k.to_s] : nil }
  end

  private

  def provider_is_known
    return if provider.blank?
    allowed = PROVIDERS[key] || []
    errors.add(:provider, "is not supported for #{key}") unless allowed.include?(provider)
  end
end
