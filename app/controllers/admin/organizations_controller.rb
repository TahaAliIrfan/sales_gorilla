module Admin
  class OrganizationsController < BaseController
    before_action :set_organization, only: %i[show destroy]

    def index
      @organizations = Organization
                         .left_joins(:memberships)
                         .select("organizations.*, COUNT(memberships.id) AS members_count")
                         .group("organizations.id")
                         .order(:name)
    end

    def show
      @members = @organization.memberships.includes(:user, :access_role).order(created_at: :desc)
      @stats = organization_stats(@organization)
    end

    def destroy
      # Require the admin to type the org name back — a deliberate guard against
      # accidentally nuking the wrong organization.
      unless params[:confirm_name].to_s.strip == @organization.name
        redirect_to admin_organization_path(@organization),
                    flash: { error: "Confirmation text did not match the organization name. Nothing was deleted." }
        return
      end

      @organization.destroy!
      redirect_to admin_organizations_path,
                  flash: { success: "Organization “#{@organization.name}” was deleted." }
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed
      # FKs to organizations are RESTRICT, so an org with leftover records
      # (customers, deals, recordings, …) can't be hard-deleted. Surface a clear
      # reason instead of a 500.
      blockers = organization_stats(@organization).select { |_, n| n.positive? }
                   .map { |label, n| "#{n} #{label}" }.join(", ")
      redirect_to admin_organization_path(@organization),
                  flash: { error: "Can't delete “#{@organization.name}” — it still has #{blockers.presence || 'related records'}. Remove those first." }
    end

    private

    def set_organization
      @organization = Organization.find(params[:id])
    end

    # Cross-org counts of the heavyweight records that block deletion. Tenant
    # scope is already lifted by Admin::BaseController.
    def organization_stats(org)
      {
        "members"   => org.memberships.count,
        "customers" => Customer.where(organization_id: org.id).count,
        "deals"     => Deal.where(organization_id: org.id).count,
        "recordings" => Recording.where(organization_id: org.id).count
      }
    end
  end
end
