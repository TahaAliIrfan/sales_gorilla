module Relay
  module NavHelper
    # Sidebar nav: [group label, items]. Each item: label/icon/path/controllers
    # that mark it active. Keep icons in sync with bin/relay_icons.
    def relay_nav_groups
      [
        ["Workspace", [
          { label: "Today",    icon: "sunrise",     path: dashboard_path,  controllers: %w[user_dashboard my_tasks_dashboard manager] },
          { label: "Leads",    icon: "users",       path: customers_path,  controllers: %w[customers csv_imports customer_followups] },
          { label: "Pipeline", icon: "layers",      path: deals_path,      controllers: %w[deals pipelines deal_stages] },
          { label: "Outreach", icon: "megaphone",   path: campaigns_path,  controllers: %w[campaigns customer_groups whatsapp_templates] },
          { label: "Insights", icon: "bar-chart-3", path: reports_path,    controllers: %w[reports] },
        ]],
        ["Money", [
          { label: "Quotes & invoices", icon: "receipt", path: invoices_path,
            controllers: %w[all_invoices invoices cost_estimates odoo_proposals milestones] },
        ]],
      ]
    end

    def relay_nav_active?(item)
      item[:controllers].include?(controller_name)
    end
  end
end
