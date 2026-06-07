# Routes scoped to an organization's tenant subdomain (e.g. acme.tecaudex.com).
# Excludes the bare domain and platform subdomains.
class TenantSubdomain
  NON_TENANT_SUBDOMAINS = %w[www admin app api crm ascolto].freeze

  def self.matches?(request)
    sub = request.subdomain.to_s.downcase
    sub.present? && NON_TENANT_SUBDOMAINS.exclude?(sub)
  end
end
