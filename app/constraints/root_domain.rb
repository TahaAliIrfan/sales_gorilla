# Routes scoped to the root/marketing/account area: bare domain or a platform
# subdomain (www / admin / app / api / crm).
class RootDomain
  def self.matches?(request)
    !TenantSubdomain.matches?(request)
  end
end
