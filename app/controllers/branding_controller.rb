# Lets owners/admins customize their organization's branding: display name,
# primary/accent colors, and logo. Operates on the current organization.
class BrandingController < TenantController
  layout "relay"
  before_action :set_organization

  def edit
    authorize @organization, :edit_branding?
  end

  def update
    authorize @organization, :update_branding?
    if @organization.update(branding_params)
      # Branding now lives in the Relay settings workspace; send the admin back
      # to its tab. (The legacy /branding edit page still renders if reached.)
      redirect_to settings_path(tab: "branding"), notice: "Branding updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_organization
    @organization = current_organization
  end

  def branding_params
    params.require(:organization).permit(:name, :primary_color, :accent_color, :logo)
  end
end
