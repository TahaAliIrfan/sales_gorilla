# Tenant-side management of connected Facebook Pages: set each page's lead
# source and disconnect (unsubscribe from leadgen). The OAuth connect itself
# happens on the root host (MetaLeadAds::ConnectionsController); this just edits
# the resulting MetaPageConnection rows for the current org.
class Settings::MetaPageConnectionsController < TenantController
  layout "relay"
  before_action :require_login
  before_action :authorize_admin
  before_action :set_connection

  def update
    if @connection.update(lead_source: params.require(:meta_page_connection).permit(:lead_source)[:lead_source])
      redirect_to settings_features_path, notice: "Lead source updated for #{@connection.page_name}."
    else
      redirect_to settings_features_path, alert: @connection.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @connection.page_access_token.present?
      MetaLeadAdsService.unsubscribe_page(page_id: @connection.page_id, page_token: @connection.page_access_token)
    end
    name = @connection.page_name
    @connection.destroy
    redirect_to settings_features_path, notice: "Disconnected #{name} from Lead Ads."
  end

  private

  def authorize_admin
    authorize OrganizationFeature, :update?
  end

  def set_connection
    @connection = MetaPageConnection.find(params[:id])
  end
end
