# Resolves the current Organization (tenant) from the request subdomain and
# hands it to acts_as_tenant, which then scopes every tenant model's queries to
# that organization for the duration of the request.
#
# On the root/marketing/admin/api domains there is no tenant subdomain, so the
# tenant is left unset and feature controllers (which inherit from
# TenantController) will refuse to render.
module SetsCurrentTenant
  extend ActiveSupport::Concern

  included do
    set_current_tenant_through_filter
    before_action :resolve_current_tenant
  end

  NON_TENANT_SUBDOMAINS = %w[www admin app api crm].freeze

  private

  def resolve_current_tenant
    return if tenant_subdomain.blank?

    organization = Organization.find_by(subdomain: tenant_subdomain)
    set_current_tenant(organization) if organization
    @current_organization = organization
  end

  def tenant_subdomain
    sub = request.subdomain.to_s.downcase
    return nil if sub.blank? || NON_TENANT_SUBDOMAINS.include?(sub)

    sub
  end

  def current_organization
    @current_organization
  end
end
