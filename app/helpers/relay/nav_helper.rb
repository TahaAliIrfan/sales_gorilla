module Relay
  module NavHelper
    # Sidebar nav: [group label, items]. Each item: label/icon/path/controllers
    # that mark it active. Keep icons in sync with bin/relay_icons.
    def relay_nav_groups
      [
        ["Workspace", [
          { label: "Today",    icon: "sunrise",     path: dashboard_path,  controllers: %w[user_dashboard my_tasks_dashboard manager] },
          { label: "Leads",    icon: "users",       path: customers_path,  controllers: %w[customers csv_imports customer_followups] },
          { label: "Inbox",    icon: "message-square", path: inbox_path,   controllers: %w[inbox], badge: relay_inbox_unread_count },
          { label: "Pipeline", icon: "layers",      path: deals_path,      controllers: %w[deals pipelines deal_stages] },
          { label: "Outreach", icon: "megaphone",   path: outreach_path,   controllers: %w[outreach campaigns customer_groups whatsapp_templates] },
          { label: "Insights", icon: "bar-chart-3", controllers: %w[reports],
            # index is admin/manager-gated; associates get their own dashboard
            path: (current_user&.admin? || current_user&.manager?) ? reports_path : my_reports_path },
        ]],
        ["Money", [
          { label: "Quotes & invoices", icon: "receipt", path: billing_path,
            controllers: %w[billing all_invoices invoices cost_estimates odoo_proposals milestones] },
        ]],
      ]
    end

    def relay_nav_active?(item)
      item[:controllers].include?(controller_name)
    end

    # Unread WhatsApp messages for the sidebar Inbox badge. One COUNT, scoped to
    # the current org by acts_as_tenant and to the user's visible leads by the
    # Customer policy scope (admins see all, associates only their own). Counts
    # inbound messages still flagged unread. Returns 0 for guests.
    def relay_inbox_unread_count
      return 0 unless respond_to?(:current_user) && current_user

      # Memoized: the sidebar calls this on every relay page render, and the
      # count is a real query against whatsapp_messages.
      @_relay_inbox_unread_count ||= WhatsappMessage
        .where(direction: "inbound", status: "received")
        .where(customer_id: policy_scope(Customer).select(:id))
        .count
    end
  end
end
