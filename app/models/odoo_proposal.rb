class OdooProposal < ApplicationRecord
  belongs_to :user
  belongs_to :customer, optional: true

  validates :deployment_type, inclusion: { in: %w[online sh on_premise] }
  validates :num_users, numericality: { greater_than: 0 }
  validates :selected_modules, presence: { message: "Please select at least one module" }

  DEPLOYMENT_LABELS = {
    'online'     => 'Odoo Online',
    'sh'         => 'Odoo.sh',
    'on_premise' => 'On-Premise'
  }.freeze

  # Odoo official subscription pricing — billed annually at $7.25 (Standard) / $10.90 (Custom)
  # Converted at ~280 PKR/USD. Standard = Online only. Custom = SH / On-Premise (+ Studio, multi-company, API).
  ODOO_SUBSCRIPTION = {
    'online'     => { plan: 'Standard', usd_monthly: 7.25,  pkr_monthly: 2_030 },
    'sh'         => { plan: 'Custom',   usd_monthly: 10.90, pkr_monthly: 3_052 },
    'on_premise' => { plan: 'Custom',   usd_monthly: 10.90, pkr_monthly: 3_052 }
  }.freeze

  # On-Premise hosting tiers — AWS EC2-based estimates at ~280 PKR/USD
  HOSTING_TIERS = {
    'basic'        => { label: 'Basic',        specs: '2 vCPU / 2 GB RAM / 20 GB SSD',   users: 'Up to 10 users',  annual_pkr: 63_384,    monthly_pkr: 5_282  },
    'standard'     => { label: 'Standard',     specs: '2 vCPU / 8 GB RAM / 50 GB SSD',   users: '10–30 users',     annual_pkr: 223_512,   monthly_pkr: 18_626 },
    'professional' => { label: 'Professional', specs: '4 vCPU / 16 GB RAM / 100 GB SSD', users: '30–100 users',    annual_pkr: 510_408,   monthly_pkr: 42_534 },
    'enterprise'   => { label: 'Enterprise',   specs: '8 vCPU / 32 GB RAM / 200 GB SSD', users: '100+ users',      annual_pkr: 1_030_824, monthly_pkr: 85_902 }
  }.freeze

  # Odoo.sh platform tiers — component pricing billed by Odoo (annual rates at ~280 PKR/USD)
  # Starter : 1 worker ($57.60) + 50 GB ($10) + 1 staging ($14.40) = ~$82/mo
  # Growth  : 2 workers ($115.20) + 100 GB ($20) + 2 stagings ($28.80) = ~$164/mo
  # Scale   : 4 workers ($230.40) + 200 GB ($40) + 3 stagings ($43.20) = ~$314/mo
  SH_TIERS = {
    'sh_starter' => { label: 'Starter', specs: '1 Worker / 50 GB Storage / 1 Staging',    users: 'Up to 15 users', annual_pkr: 275_520,   monthly_pkr: 22_960 },
    'sh_growth'  => { label: 'Growth',  specs: '2 Workers / 100 GB Storage / 2 Stagings', users: '15–50 users',    annual_pkr: 551_040,   monthly_pkr: 45_920 },
    'sh_scale'   => { label: 'Scale',   specs: '4 Workers / 200 GB Storage / 3 Stagings', users: '50+ users',      annual_pkr: 1_053_696, monthly_pkr: 87_808 }
  }.freeze

  DEPLOYMENT_OPTIONS = [
    { key: 'online',     label: 'Odoo Online', plan: 'Standard', desc: 'Fully managed SaaS by Odoo. Standard plan — all apps included.' },
    { key: 'sh',         label: 'Odoo.sh',     plan: 'Custom',   desc: 'Git-based cloud by Odoo. Custom plan — includes Studio & API.' },
    { key: 'on_premise', label: 'On-Premise',  plan: 'Custom',   desc: 'Self-hosted on your infrastructure. Custom plan — full control.' }
  ].freeze

  MODULES = {
    'Sales & CRM' => [
      { key: 'crm',       label: 'CRM',        description: 'Leads, opportunities and sales pipeline', impl_cost: 30_000 },
      { key: 'sales',     label: 'Sales',       description: 'Quotations, orders and pricing rules',   impl_cost: 40_000 },
      { key: 'invoicing', label: 'Invoicing',   description: 'Customer invoices, payments & reports',  impl_cost: 35_000 }
    ],
    'Operations' => [
      { key: 'inventory', label: 'Inventory',     description: 'Stock management and warehousing',       impl_cost: 55_000 },
      { key: 'purchase',  label: 'Purchase',      description: 'Purchase orders and vendor management',  impl_cost: 45_000 },
      { key: 'pos',       label: 'Point of Sale', description: 'Retail and restaurant POS',              impl_cost: 65_000 },
      { key: 'website',   label: 'Website',       description: 'Company website builder',                impl_cost: 50_000 },
      { key: 'ecommerce', label: 'eCommerce',     description: 'Online store with payments',             impl_cost: 85_000 }
    ],
    'HR & Payroll' => [
      { key: 'employees', label: 'Employees',  description: 'Employee records and org chart',       impl_cost: 30_000 },
      { key: 'time_off',  label: 'Time Off',   description: 'Leave requests and approvals',         impl_cost: 25_000 },
      { key: 'payroll',   label: 'Payroll',    description: 'Salary processing and payslips',       impl_cost: 65_000 }
    ],
    'Manufacturing' => [
      { key: 'manufacturing', label: 'Manufacturing', description: 'Production orders and BOM',     impl_cost: 85_000 },
      { key: 'quality',       label: 'Quality',       description: 'Quality checks and control',    impl_cost: 55_000 }
    ],
    'Services & Marketing' => [
      { key: 'project',              label: 'Project',              description: 'Project management and tasks',       impl_cost: 45_000 },
      { key: 'timesheets',           label: 'Timesheets',           description: 'Time tracking and billing',          impl_cost: 28_000 },
      { key: 'helpdesk',             label: 'Helpdesk',             description: 'Customer support and SLA',           impl_cost: 45_000 },
      { key: 'email_marketing',      label: 'Email Marketing',      description: 'Campaigns and mailing lists',        impl_cost: 38_000 },
      { key: 'marketing_automation', label: 'Marketing Automation', description: 'Automated marketing campaigns',      impl_cost: 55_000 },
      { key: 'maintenance',          label: 'Maintenance',          description: 'Equipment maintenance scheduling',   impl_cost: 42_000 },
      { key: 'field_service',        label: 'Field Service',        description: 'On-site service dispatch',           impl_cost: 50_000 },
      { key: 'planning',             label: 'Planning',             description: 'Resource and shift planning',        impl_cost: 35_000 }
    ]
  }.freeze

  # ── Helpers ────────────────────────────────────────────────────────────────

  def display_name
    customer&.name || customer_name.presence || 'Unknown Client'
  end

  def deployment_label
    DEPLOYMENT_LABELS[deployment_type] || deployment_type
  end

  def hosting_tier_info
    HOSTING_TIERS[hosting_tier] if hosting_tier.present?
  end

  def sh_tier_info
    SH_TIERS[hosting_tier] if deployment_type == 'sh' && hosting_tier.present?
  end

  def current_tier_info
    case deployment_type
    when 'on_premise' then hosting_tier_info
    when 'sh'         then sh_tier_info
    end
  end

  def selected_module_details
    all_modules = MODULES.values.flatten
    selected_modules.map { |key| all_modules.find { |m| m[:key] == key } }.compact
  end

  # ── Subscription (Odoo — paid to Odoo, shown for reference) ───────────────

  def odoo_subscription_info
    ODOO_SUBSCRIPTION[deployment_type] || ODOO_SUBSCRIPTION['online']
  end

  def subscription_monthly_per_user
    odoo_subscription_info[:pkr_monthly]
  end

  def subscription_monthly_total
    subscription_monthly_per_user * num_users
  end

  def subscription_yearly_total
    subscription_monthly_total * 12
  end

  # ── Hosting ────────────────────────────────────────────────────────────────

  def hosting_monthly
    current_tier_info&.dig(:monthly_pkr).to_i
  end

  def hosting_yearly
    annual_hosting_cost.to_i
  end

  # ── One-time ───────────────────────────────────────────────────────────────

  def total_cost
    implementation_fee + annual_hosting_cost
  end

  # ── Year 1 & Recurring ─────────────────────────────────────────────────────

  def year_1_total
    implementation_fee.to_i + subscription_yearly_total + hosting_yearly
  end

  def year_2_recurring_yearly
    subscription_yearly_total + hosting_yearly
  end

  def year_2_recurring_monthly
    subscription_monthly_total + hosting_monthly
  end

  # ── Calculations (called before save) ─────────────────────────────────────

  def calculate_implementation_fee
    selected_module_details.sum { |m| m[:impl_cost] }
  end

  def calculate_annual_hosting_cost
    current_tier_info&.dig(:annual_pkr).to_i
  end
end
