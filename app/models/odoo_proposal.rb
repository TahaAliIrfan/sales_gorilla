class OdooProposal < ApplicationRecord
  belongs_to :user
  belongs_to :customer, optional: true

  validates :deployment_type, inclusion: { in: %w[online sh on_premise] }
  validates :num_users, numericality: { greater_than: 0 }
  validate :must_have_at_least_one_module

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

  INDUSTRIES = [
    'Manufacturing',
    'Retail / eCommerce',
    'Distribution / Wholesale',
    'Services / Consulting',
    'Healthcare',
    'Education',
    'Construction',
    'Real Estate',
    'Hospitality',
    'Logistics / Transportation',
    'Technology / Software',
    'Non-Profit',
    'Other'
  ].freeze

  COMPANY_SIZES = [
    ['1–10 employees',    '1-10'],
    ['11–50 employees',   '11-50'],
    ['51–200 employees',  '51-200'],
    ['201–500 employees', '201-500'],
    ['500+ employees',    '500+']
  ].freeze

  PAIN_POINTS = [
    'Manual data entry / spreadsheet chaos',
    'Inventory tracking and stock visibility',
    'Sales pipeline & lead management',
    'Customer follow-up gaps',
    'Payroll & HR overhead',
    'Multi-location / multi-branch coordination',
    'Reporting & business analytics',
    'Disconnected systems (no single source of truth)',
    'Field service / dispatch coordination',
    'Manufacturing floor & production visibility',
    'Customer support & ticket backlog',
    'Marketing campaign tracking & ROI',
    'Procurement & vendor management',
    'Project & timesheet management',
    'Compliance & audit trail'
  ].freeze

  MODULES = {
    'Finance' => [
      { key: 'accounting', label: 'Accounting',  description: 'Full double-entry accounting, GL, banking, taxes & reports', impl_cost: 75_000 },
      { key: 'invoicing',  label: 'Invoicing',   description: 'Customer invoices, payments, follow-ups & reminders',         impl_cost: 35_000 },
      { key: 'expenses',   label: 'Expenses',    description: 'Employee expense submission, approval & reimbursement',       impl_cost: 30_000 },
      { key: 'documents',  label: 'Documents',   description: 'Centralised document management with workflow rules',         impl_cost: 35_000 },
      { key: 'sign',       label: 'Sign',        description: 'Send and sign documents electronically',                       impl_cost: 25_000 },
      { key: 'spreadsheet', label: 'Spreadsheet', description: 'Live dashboards and pivot reports backed by Odoo data',      impl_cost: 30_000 }
    ],
    'Sales & CRM' => [
      { key: 'crm',           label: 'CRM',            description: 'Leads, opportunities and sales pipeline',          impl_cost: 30_000 },
      { key: 'sales',         label: 'Sales',          description: 'Quotations, orders and pricing rules',             impl_cost: 40_000 },
      { key: 'pos',           label: 'Point of Sale',  description: 'Retail and restaurant POS',                        impl_cost: 65_000 },
      { key: 'subscriptions', label: 'Subscriptions',  description: 'Recurring billing for SaaS or service contracts',  impl_cost: 45_000 },
      { key: 'rental',        label: 'Rental',         description: 'Rent products with availability & deposits',       impl_cost: 40_000 }
    ],
    'Inventory & Purchase' => [
      { key: 'inventory', label: 'Inventory',  description: 'Stock management, multi-warehouse & lots/serials',  impl_cost: 55_000 },
      { key: 'purchase',  label: 'Purchase',   description: 'RFQs, purchase orders & vendor management',         impl_cost: 45_000 },
      { key: 'barcode',   label: 'Barcode',    description: 'Barcode-driven warehouse operations',                impl_cost: 30_000 }
    ],
    'Manufacturing' => [
      { key: 'manufacturing', label: 'Manufacturing',           description: 'Production orders, BOM & work centres',  impl_cost: 85_000 },
      { key: 'plm',           label: 'Product Lifecycle (PLM)', description: 'Engineering change orders & BOM versions', impl_cost: 60_000 },
      { key: 'maintenance',   label: 'Maintenance',             description: 'Preventive & corrective maintenance',     impl_cost: 42_000 },
      { key: 'quality',       label: 'Quality',                 description: 'Quality checks, alerts and control',      impl_cost: 55_000 },
      { key: 'repairs',       label: 'Repairs',                 description: 'Repair orders for returned products',      impl_cost: 35_000 }
    ],
    'HR & Payroll' => [
      { key: 'employees',   label: 'Employees',   description: 'Employee records, org chart & directory',     impl_cost: 30_000 },
      { key: 'recruitment', label: 'Recruitment', description: 'Job postings, applicants & hiring pipeline',  impl_cost: 45_000 },
      { key: 'time_off',    label: 'Time Off',    description: 'Leave requests, balances & approvals',        impl_cost: 25_000 },
      { key: 'attendances', label: 'Attendances', description: 'Clock-in/out tracking, kiosk & badge mode',   impl_cost: 30_000 },
      { key: 'payroll',     label: 'Payroll',     description: 'Salary processing, payslips & contracts',     impl_cost: 65_000 },
      { key: 'appraisals',  label: 'Appraisals',  description: 'Periodic performance reviews & 360 feedback', impl_cost: 35_000 },
      { key: 'referrals',   label: 'Referrals',   description: 'Employee referral program with rewards',       impl_cost: 22_000 },
      { key: 'fleet',       label: 'Fleet',       description: 'Company vehicle tracking & service history',  impl_cost: 35_000 },
      { key: 'approvals',   label: 'Approvals',   description: 'Customisable approval requests across teams',  impl_cost: 25_000 }
    ],
    'Marketing' => [
      { key: 'email_marketing',      label: 'Email Marketing',      description: 'Campaigns, mailing lists & A/B testing',     impl_cost: 38_000 },
      { key: 'sms_marketing',        label: 'SMS Marketing',        description: 'Bulk SMS campaigns with templates',           impl_cost: 30_000 },
      { key: 'social_marketing',     label: 'Social Marketing',     description: 'Schedule & track posts across social media', impl_cost: 35_000 },
      { key: 'marketing_automation', label: 'Marketing Automation', description: 'Multi-step automated nurture journeys',      impl_cost: 55_000 },
      { key: 'events',               label: 'Events',               description: 'Event registration, tickets & agenda',        impl_cost: 45_000 },
      { key: 'surveys',              label: 'Surveys',              description: 'Customer & employee surveys with scoring',    impl_cost: 28_000 }
    ],
    'Website & eCommerce' => [
      { key: 'website',   label: 'Website',     description: 'Drag-and-drop company website builder',  impl_cost: 50_000 },
      { key: 'ecommerce', label: 'eCommerce',   description: 'Online store with payments & shipping',  impl_cost: 85_000 },
      { key: 'blog',      label: 'Blog',        description: 'Built-in blog with SEO and comments',     impl_cost: 25_000 },
      { key: 'forum',     label: 'Forum',       description: 'Community forum with karma & moderation', impl_cost: 28_000 },
      { key: 'live_chat', label: 'Live Chat',   description: 'Website live chat with operator console', impl_cost: 28_000 },
      { key: 'elearning', label: 'eLearning',   description: 'Courses, quizzes & certifications',       impl_cost: 50_000 }
    ],
    'Services' => [
      { key: 'project',       label: 'Project',       description: 'Project management, tasks & Kanban boards', impl_cost: 45_000 },
      { key: 'timesheets',    label: 'Timesheets',    description: 'Time tracking with invoicing integration',  impl_cost: 28_000 },
      { key: 'helpdesk',      label: 'Helpdesk',      description: 'Customer support tickets with SLA',          impl_cost: 45_000 },
      { key: 'field_service', label: 'Field Service', description: 'On-site service dispatch & scheduling',      impl_cost: 50_000 },
      { key: 'planning',      label: 'Planning',      description: 'Resource and shift planning',                impl_cost: 35_000 },
      { key: 'appointments',  label: 'Appointments',  description: 'Online appointment booking with calendar',   impl_cost: 30_000 }
    ],
    'Productivity & Custom' => [
      { key: 'discuss',   label: 'Discuss',           description: 'Internal messaging, channels & threads',         impl_cost: 18_000 },
      { key: 'knowledge', label: 'Knowledge',         description: 'Internal wiki with hierarchical articles',       impl_cost: 35_000 },
      { key: 'voip',      label: 'VoIP',              description: 'Click-to-call integration with softphones',      impl_cost: 35_000 },
      { key: 'iot',       label: 'IoT Box',           description: 'Connect scales, printers and scanners',          impl_cost: 50_000 },
      { key: 'studio',    label: 'Studio (Custom Apps)', description: 'No-code customisation and custom modules',    impl_cost: 75_000 }
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

  # Custom (AI-suggested or user-entered) modules not in the official Odoo catalog.
  # Stored as jsonb array of { "label", "description", "impl_cost" }.
  def custom_module_details
    Array(custom_modules).filter_map do |m|
      next nil if m.blank?
      m = m.with_indifferent_access if m.is_a?(Hash)
      label = m['label'].to_s.strip
      next nil if label.empty?
      {
        key:         "custom_#{label.parameterize(separator: '_')}",
        label:       label,
        description: m['description'].to_s.strip,
        impl_cost:   m['impl_cost'].to_i,
        hours:       m['hours'].to_i,
        custom:      true
      }
    end
  end

  def custom_modules_total
    custom_module_details.sum { |m| m[:impl_cost] }
  end

  def all_module_details
    selected_module_details + custom_module_details
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
    selected_module_details.sum { |m| m[:impl_cost] } + custom_modules_total
  end

  def calculate_annual_hosting_cost
    current_tier_info&.dig(:annual_pkr).to_i
  end

  # ── AI narrative ──────────────────────────────────────────────────────────

  def narrative_generated?
    narrative_generated_at.present?
  end

  def pain_points_array
    Array(pain_points).reject(&:blank?)
  end

  def module_justification_for(key)
    return nil if claude_module_justifications.blank?
    claude_module_justifications[key.to_s] || claude_module_justifications[key.to_sym.to_s]
  end

  private

  def must_have_at_least_one_module
    return if Array(selected_modules).reject(&:blank?).any? ||
              custom_module_details.any?
    errors.add(:base, "Please select at least one module or add a custom module")
  end
end
