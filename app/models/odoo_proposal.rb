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

  HOSTING_TIERS = {
    'basic'        => { label: 'Basic',        specs: '2 vCPU / 2GB RAM / 20GB SSD', users: 'Up to 10 users',    annual_pkr: 63_384 },
    'standard'     => { label: 'Standard',     specs: '2 vCPU / 8GB RAM / 50GB SSD', users: '10–30 users',      annual_pkr: 223_512 },
    'professional' => { label: 'Professional', specs: '4 vCPU / 16GB RAM / 100GB SSD', users: '30–100 users',   annual_pkr: 510_408 },
    'enterprise'   => { label: 'Enterprise',   specs: '8 vCPU / 32GB RAM / 200GB SSD', users: '100+ users',     annual_pkr: 1_030_824 }
  }.freeze

  DEPLOYMENT_OPTIONS = [
    { key: 'online',     label: 'Odoo Online', icon: 'Cloud', desc: 'Fully managed SaaS by Odoo. Easiest to start, no server management.' },
    { key: 'sh',         label: 'Odoo.sh',      icon: 'Flash', desc: 'Managed cloud with full customisation support and Git integration.' },
    { key: 'on_premise', label: 'On-Premise',   icon: 'Server', desc: 'Install on your own infrastructure. Full control, annual hosting fee.' }
  ].freeze

  MODULES = {
    'Sales & CRM' => [
      { key: 'crm',       label: 'CRM',       description: 'Manage leads, opportunities and pipeline', impl_cost: 30_000 },
      { key: 'sales',     label: 'Sales',     description: 'Quotations, orders and pricing rules',    impl_cost: 35_000 },
      { key: 'invoicing', label: 'Invoicing', description: 'Customer invoices, payments and reports',  impl_cost: 30_000 }
    ],
    'Operations' => [
      { key: 'inventory', label: 'Inventory',    description: 'Stock management and warehouse operations', impl_cost: 50_000 },
      { key: 'purchase',  label: 'Purchase',     description: 'Purchase orders and vendor management',    impl_cost: 40_000 },
      { key: 'pos',       label: 'Point of Sale', description: 'Retail and restaurant POS system',        impl_cost: 55_000 },
      { key: 'website',   label: 'Website',      description: 'Build and manage your company website',   impl_cost: 45_000 },
      { key: 'ecommerce', label: 'eCommerce',    description: 'Online store with payments integration',  impl_cost: 75_000 }
    ],
    'HR & Payroll' => [
      { key: 'employees', label: 'Employees',  description: 'Employee records, contracts and org chart', impl_cost: 30_000 },
      { key: 'time_off',  label: 'Time Off',   description: 'Leave requests and approval workflows',     impl_cost: 25_000 },
      { key: 'payroll',   label: 'Payroll',    description: 'Salary processing and payslip generation',  impl_cost: 60_000 }
    ],
    'Manufacturing' => [
      { key: 'manufacturing', label: 'Manufacturing', description: 'Production orders and BOM management', impl_cost: 80_000 },
      { key: 'quality',       label: 'Quality',       description: 'Quality checks and control points',   impl_cost: 50_000 }
    ],
    'Services & Marketing' => [
      { key: 'project',               label: 'Project',               description: 'Project management and task tracking',    impl_cost: 40_000 },
      { key: 'timesheets',            label: 'Timesheets',            description: 'Employee time tracking and billing',      impl_cost: 25_000 },
      { key: 'helpdesk',              label: 'Helpdesk',              description: 'Customer support tickets and SLA',        impl_cost: 40_000 },
      { key: 'email_marketing',       label: 'Email Marketing',       description: 'Email campaigns and mailing lists',       impl_cost: 35_000 },
      { key: 'marketing_automation',  label: 'Marketing Automation',  description: 'Automated multi-step marketing campaigns', impl_cost: 50_000 },
      { key: 'maintenance',           label: 'Maintenance',           description: 'Equipment maintenance and scheduling',    impl_cost: 40_000 },
      { key: 'field_service',         label: 'Field Service',         description: 'On-site service and technician dispatch', impl_cost: 45_000 },
      { key: 'planning',              label: 'Planning',              description: 'Resource and shift planning',             impl_cost: 35_000 }
    ]
  }.freeze

  def display_name
    customer&.name || customer_name || 'Unknown Client'
  end

  def deployment_label
    DEPLOYMENT_LABELS[deployment_type] || deployment_type
  end

  def hosting_tier_info
    HOSTING_TIERS[hosting_tier] if hosting_tier.present?
  end

  def selected_module_details
    all_modules = MODULES.values.flatten
    selected_modules.map { |key| all_modules.find { |m| m[:key] == key } }.compact
  end

  def total_cost
    implementation_fee + annual_hosting_cost
  end

  def calculate_implementation_fee
    selected_module_details.sum { |m| m[:impl_cost] }
  end

  def calculate_annual_hosting_cost
    return 0 if deployment_type == 'online'
    HOSTING_TIERS[hosting_tier]&.dig(:annual_pkr) || 0
  end
end
