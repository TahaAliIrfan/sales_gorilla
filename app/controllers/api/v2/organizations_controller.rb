# Mobile-side organization picker and switcher.
#
# Listing the user's orgs doesn't need a tenant scope (the picker decides which
# tenant to use), so `index` skips tenant resolution. `switch` mints a fresh
# JWT that encodes the chosen organization_id — subsequent requests then resolve
# tenant directly from the token without any per-request header.
class Api::V2::OrganizationsController < Api::V2::BaseController
  skip_before_action :resolve_current_tenant, only: %i[index switch]

  def index
    orgs = current_user.organizations.order(:name)
    render_success(orgs.map { |org| organization_payload(org) })
  end

  def switch
    org = current_user.organizations.find_by(id: params[:id]) ||
          current_user.organizations.find_by(subdomain: params[:subdomain].to_s.downcase)

    if org.nil?
      return render_error("You aren't a member of that organization", nil, :forbidden)
    end

    token = JsonWebToken.encode(user_id: current_user.id, organization_id: org.id)
    render_success(
      {
        token: token,
        organization: organization_payload(org)
      },
      "Switched to #{org.name}"
    )
  end

  # Current organization details (branding + role) for the active token.
  def show
    render_success(organization_payload(current_organization))
  end

  private

  def organization_payload(org)
    return nil unless org
    {
      id:            org.id,
      name:          org.name,
      subdomain:     org.subdomain,
      primary_color: org.primary_color,
      accent_color:  org.accent_color,
      logo_url:      (org.logo.attached? ? Rails.application.routes.url_helpers.url_for(org.logo) : nil),
      role:          current_user.membership_for(org)&.role
    }
  rescue
    { id: org.id, name: org.name, subdomain: org.subdomain, primary_color: org.primary_color, accent_color: org.accent_color, logo_url: nil }
  end
end
