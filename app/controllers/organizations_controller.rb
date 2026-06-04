# Organization management on the root domain: a signed-in user lists the orgs
# they belong to, and can create a new one (becoming its owner).
class OrganizationsController < ApplicationController
  layout "marketing"
  before_action :require_login

  def index
    @organizations = current_user.organizations.order(:name)
  end

  def new
    @organization = Organization.new
  end

  # Live availability check for the new-org form. Returns JSON.
  def check_subdomain
    subdomain = params[:subdomain].to_s.strip.downcase
    candidate = Organization.new(name: "placeholder", subdomain: subdomain)
    candidate.valid?
    errors = candidate.errors[:subdomain]

    render json: {
      subdomain: subdomain,
      available: subdomain.present? && errors.empty?,
      message: subdomain.blank? ? "Enter a subdomain" : (errors.first || "Available")
    }
  end

  def create
    @organization = Organization.new(organization_params)

    Organization.transaction do
      @organization.save!
      @organization.memberships.create!(user: current_user, role: "owner")
    end

    redirect_to tenant_root_url(subdomain: @organization.subdomain, host: tenant_host(@organization.subdomain)),
                allow_other_host: true,
                notice: "Organization created."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private

  def organization_params
    params.require(:organization).permit(:name, :subdomain)
  end

  # Replace the current subdomain (if any) with the new tenant's subdomain.
  def tenant_host(subdomain)
    parts = request.host.split(".")
    parts.shift if parts.first.in?(%w[www admin app api crm]) || parts.length > 2
    "#{subdomain}.#{parts.join('.')}"
  end
end
