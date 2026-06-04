module ApplicationHelper
  # Inline CSS custom properties carrying an organization's brand colors, so the
  # whole tenant UI themes itself via `bg-[var(--brand-primary)]` etc. without
  # recompiling Tailwind per organization.
  def brand_style(organization)
    primary = organization&.primary_color || Organization::DEFAULT_PRIMARY_COLOR
    accent  = organization&.accent_color  || Organization::DEFAULT_ACCENT_COLOR
    "--brand-primary: #{primary}; --brand-accent: #{accent}; " \
      "--brand-primary-soft: #{primary}1a; --brand-accent-soft: #{accent}1a;"
  end

  def flash_accent(level)
    case level.to_sym
    when :notice, :success then "var(--color-accent-bright)"
    when :alert, :error    then "#c0492f"
    else "var(--color-ink-soft)"
    end
  end

  # Sidebar navigation link (dark sidebar). Active = brand left rule + subtle
  # wash + bright text; resting items are muted, hover lifts toward white.
  def nav_link(label, path, icon:, active: nil)
    active = current_page?(path) if active.nil?
    classes = ["group relative flex items-center gap-3 rounded-md px-3 py-2.5 text-sm font-medium transition"]
    classes << (active ? "bg-[var(--color-line-2)] text-ink" : "text-ink-soft hover:bg-[var(--color-line)] hover:text-ink")
    link_to path, class: classes.join(" ") do
      rule = active ? content_tag(:span, "", class: "absolute left-0 top-2 bottom-2 w-[3px] rounded-full",
                                    style: "background: var(--brand-accent, var(--color-accent))") : "".html_safe
      safe_join([rule, nav_icon(icon), content_tag(:span, label)])
    end
  end

  def nav_icon(name)
    paths = {
      "grid"      => '<path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z"/>',
      "users"     => '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM22 21v-2a4 4 0 0 0-3-3.87M16 3.13A4 4 0 0 1 16 11"/>',
      "swatch"    => '<path d="M4 17a3 3 0 1 0 6 0V5a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2zM10 13l5-5M14 7l3 3-7 7M10 20h9a2 2 0 0 0 2-2v-2a2 2 0 0 0-2-2h-2"/>',
      "cog"       => '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>',
      "phone"     => '<path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.37 1.9.72 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.35 1.85.59 2.81.72A2 2 0 0 1 22 16.92z"/>',
      "deal"      => '<path d="M12 1v22M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>',
      "task"      => '<path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>',
      "rec"       => '<path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2M12 19v4M8 23h8"/>',
      "graph"     => '<path d="M3 3v18h18"/><path d="M7 14l4-4 4 4 6-6"/>',
      "megaphone" => '<path d="M3 11l16-7v16L3 13zM7 19a4 4 0 0 0 4-4M19 4v16"/>',
      "doc"       => '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/><path d="M16 13H8M16 17H8M10 9H8"/>',
      "calc"      => '<rect x="4" y="2" width="16" height="20" rx="2"/><path d="M8 6h8M8 10h2M12 10h2M16 10h.01M8 14h.01M12 14h.01M16 14h.01M8 18h2M12 18h.01M16 18h.01"/>',
      "users-2"   => '<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM23 21v-2a4 4 0 0 0-3-3.87M16 3.13A4 4 0 0 1 16 11"/>'
    }
    raw %(<svg class="h-5 w-5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">#{paths[name] || paths["grid"]}</svg>)
  end

  def input_classes
    "mt-1 block w-full rounded-md border-0 bg-paper px-3.5 py-2.5 text-ink shadow-sm ring-1 " \
      "ring-[var(--color-line-2)] transition placeholder:text-ink-soft/50 focus:bg-panel focus:outline-none " \
      "focus:ring-2 focus:ring-[var(--brand-primary)] sm:text-sm"
  end

  def public_input_classes
    "mt-1 block w-full rounded-md border-0 bg-paper px-3.5 py-2.5 text-ink shadow-sm ring-1 " \
      "ring-[var(--color-line-2)] transition placeholder:text-ink-soft/50 focus:bg-panel focus:outline-none " \
      "focus:ring-2 focus:ring-accent sm:text-sm"
  end

  def current_member_orgs
    return Organization.none unless current_user
    @current_member_orgs ||= current_user.organizations.order(:name)
  end

  # The full host for a tenant subdomain, preserving the current request's TLD
  # (so links between dev/staging/prod all keep working).
  def tenant_host_for(subdomain)
    parts = request.host.split(".")
    parts.shift if parts.first.in?(%w[www admin app api crm]) || parts.length > 2
    "#{subdomain}.#{parts.join('.')}"
  end

  def root_host_for_request
    parts = request.host.split(".")
    parts.shift if parts.first.in?(%w[www admin app api crm]) || parts.length > 2
    parts.join(".")
  end

  def format_activity_action(action)
    case action
    when 'created' then 'Deal Created'
    when 'updated' then 'Deal Updated'
    when 'stage_changed' then 'Stage Changed'
    when 'user_assigned' then 'User Assigned'
    when 'marked_won' then 'Marked as Won'
    when 'marked_lost' then 'Marked as Lost'
    when 'deleted' then 'Deal Deleted'
    else action.humanize
    end
  end
  
  def activity_color_class(action)
    case action
    when 'created' then 'bg-blue-500'
    when 'updated' then 'bg-yellow-500'
    when 'stage_changed' then 'bg-purple-500'
    when 'user_assigned' then 'bg-indigo-500'
    when 'marked_won' then 'bg-green-500'
    when 'marked_lost' then 'bg-red-500'
    when 'deleted' then 'bg-gray-500'
    else 'bg-gray-400'
    end
  end

  def sortable(column, title = nil)
    title ||= column.titleize
    direction = (column == params[:sort] && params[:direction] == "asc") ? "desc" : "asc"
    icon = column == params[:sort] ? (params[:direction] == "asc" ? "↑" : "↓") : ""
    
    link_to "#{title} #{icon}".html_safe, 
            { sort: column, direction: direction, search: params[:search], user_id: params[:user_id] },
            class: "hover:text-gray-900"
  end
  
  # Determine country label based on phone number prefix
  def get_country_label(phone_number)
    case phone_number
    when /^\+1/ 
      "US Number"
    when /^\+44/
      "UK Number"
    when /^\+61/
      "AUS Number"
    else
      "Other Number"
    end
  end
  
  # Helper for complexity color classes in cost estimates
  def complexity_color(complexity)
    case complexity&.downcase
    when 'low'
      'bg-green-100 text-green-800'
    when 'high'
      'bg-red-100 text-red-800'
    when 'medium'
    else
      'bg-yellow-100 text-yellow-800'
    end
  end
end
