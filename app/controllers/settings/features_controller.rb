# Lets organization admins enable/disable feature modules (Calling first,
# Messaging/Email coming later) and configure the provider credentials for
# each enabled module.
class Settings::FeaturesController < TenantController
  layout "relay"
  before_action :require_login
  before_action :load_features, only: %i[index]
  before_action :load_feature,  only: %i[update test verify]

  def index
    authorize OrganizationFeature
  end

  def update
    authorize @feature

    if @feature.update(feature_params)
      redirect_to settings_features_path, notice: "#{@feature.key.titleize} settings saved."
    else
      load_features
      render :index, status: :unprocessable_entity
    end
  end

  # Provider-specific diagnostic. Currently only meta_conversions implements one.
  # Posts a synthetic event to the provider and returns the result as JSON for
  # the form to render inline. Does not persist anything.
  def test
    authorize @feature, :update?

    result = case @feature.key
             when "meta_conversions"
               MetaConversionsApiService.new(organization: current_organization).send_test_event
             else
               { success: false, error: "No test handler for #{@feature.key}" }
             end

    render json: result
  end

  # Verifies the configured credentials map to a real provider resource. For
  # meta_conversions this fetches pixel metadata from Meta's Graph API,
  # catching the "wrong pixel id" or "wrong token" failure mode before any
  # real event is sent.
  def verify
    authorize @feature, :update?

    result = case @feature.key
             when "meta_conversions"
               MetaConversionsApiService.new(organization: current_organization).verify_pixel
             else
               { ok: false, error: "No verify handler for #{@feature.key}" }
             end

    render json: result
  end

  private

  def load_features
    existing = current_organization.features.index_by(&:key)
    @features = OrganizationFeature::KEYS.map do |key|
      existing[key] || current_organization.features.build(key: key)
    end
  end

  def load_feature
    key = params[:key] || params[:id]
    raise ActiveRecord::RecordNotFound unless OrganizationFeature::KEYS.include?(key)

    @feature = current_organization.features.find_or_initialize_by(key: key)
  end

  # Whitelist of setting keys any feature may store. Anything else in
  # `params[:organization_feature][:settings]` is dropped.
  ALLOWED_SETTING_KEYS = %w[
    pixel_id access_token test_event_code events_enabled eligible_sources
    customer_status_mappings deal_stage_mappings source_action_sources
    lead_form_mappings
    api_key model server_url
    account_sid auth_token application_sid api_secret default_caller_id app_url
    sender_number
  ].freeze

  # Setting keys whose VALUES are hashes (status->event, source->{...}). These
  # round-trip differently from scalars/arrays: blank inner values mean "unmap
  # this entry", and the submitted hash REPLACES the saved one in full.
  HASH_SETTING_KEYS = %w[customer_status_mappings deal_stage_mappings source_action_sources lead_form_mappings].freeze

  # Merge submitted settings into the existing hash so that:
  #   - Blank scalar values (secret fields) PRESERVE the saved value
  #   - Array values REPLACE the saved value (so unchecking all boxes wipes it)
  #   - Hash values REPLACE the saved value with blank inner entries dropped
  #   - Keys not in ALLOWED_SETTING_KEYS are silently dropped
  def feature_params
    base = params.require(:organization_feature).permit(:enabled, :provider)

    raw_settings = params.dig(:organization_feature, :settings)
    raw_settings = raw_settings.to_unsafe_h if raw_settings.respond_to?(:to_unsafe_h)
    raw_settings ||= {}

    cleaned = raw_settings.each_with_object({}) do |(key, value), acc|
      key_s = key.to_s
      next unless ALLOWED_SETTING_KEYS.include?(key_s)

      acc[key_s] =
        if HASH_SETTING_KEYS.include?(key_s) && value.is_a?(Hash)
          clean_mapping_hash(value)
        elsif value.is_a?(Array)
          value.reject(&:blank?)
        else
          value if value.present?
        end

      acc.delete(key_s) if acc[key_s].nil?
    end

    merged = (@feature.settings_hash || {}).merge(cleaned)
    base.merge(settings: merged)
  end

  # Drops blank entries from a mapping hash. For source_action_sources where
  # the value is itself a {action_source:, require_lead_id:} hash, normalizes
  # the boolean and drops the row if action_source is blank.
  def clean_mapping_hash(hash)
    hash.each_with_object({}) do |(k, v), acc|
      if v.is_a?(Hash)
        action_source = v["action_source"].to_s.strip
        next if action_source.blank?
        acc[k] = {
          "action_source"   => action_source,
          "require_lead_id" => ActiveModel::Type::Boolean.new.cast(v["require_lead_id"])
        }
      else
        next if v.to_s.strip.blank?
        acc[k] = v.to_s.strip
      end
    end
  end
end
