# Lets owners/admins customize their organization's branding: display name,
# primary/accent colors, and logo. Operates on the current organization.
class BrandingController < TenantController
  before_action :set_organization

  def edit
    authorize @organization, :edit_branding?
  end

  def update
    authorize @organization, :update_branding?
    if @organization.update(branding_params)
      redirect_to edit_branding_path, notice: "Branding updated."
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
