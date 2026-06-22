# Picks an industry demo template for a lead and asks the demo server to build
# a branded Odoo demo. Returns the demo coordinates { url, db, login, password }.
class DemoBuilderService
  INDUSTRY_TEMPLATES = {
    "Manufacturing"    => "manufacturing",
    "Retail/Ecommerce" => "retail",
    "Real Estate"      => "realestate",
    "Healthcare"       => "services",
    "Technology"       => "services",
    "Services"         => "services",
    "Other"            => "services"
  }.freeze
  DEFAULT_TEMPLATE = "services".freeze

  def self.call(customer) = new(customer).call

  def initialize(customer)
    @customer = customer
  end

  def call
    Demo::ServerClient.for_organization(@customer.organization).build(
      company: company_name,
      industry: template,
      brand: @customer.organization&.primary_color,
      ref: @customer.id
    )
  end

  private

  def template
    INDUSTRY_TEMPLATES[@customer.industry] || DEFAULT_TEMPLATE
  end

  def company_name
    @customer.company.presence || @customer.name.presence || "Demo Co"
  end
end
