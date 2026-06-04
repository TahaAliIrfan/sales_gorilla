class OrganizationFeature < ApplicationRecord
  KEYS = %w[calling].freeze

  PROVIDERS = {
    "calling" => %w[twilio].freeze
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
