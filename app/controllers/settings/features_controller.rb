# Lets organization admins enable/disable feature modules (Calling first,
# Messaging/Email coming later) and configure the provider credentials for
# each enabled module.
class Settings::FeaturesController < TenantController
  before_action :require_login
  before_action :load_features, only: %i[index]
  before_action :load_feature,  only: %i[update]

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

  # Secrets (account_sid, auth_token, etc.) are never re-displayed in the form.
  # If a credential field is submitted blank, keep the existing value rather
  # than wiping it.
  def feature_params
    raw = params.require(:organization_feature).permit(
      :enabled,
      :provider,
      settings: {}
    )

    submitted_settings = raw.delete(:settings) || {}
    merged_settings = (@feature.settings_hash || {}).merge(
      submitted_settings.to_h.reject { |_, v| v.blank? }
    )

    raw.merge(settings: merged_settings)
  end
end
