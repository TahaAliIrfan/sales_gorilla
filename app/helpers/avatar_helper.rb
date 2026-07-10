module AvatarHelper
  # Customer avatar = a branded tile for the lead's SOURCE (Odoo, CCR, Inbound,
  # WhatsApp, Website, …) — an icon + source colour instead of initials, so the
  # channel a lead came from is recognisable at a glance.
  #
  #   <%= customer_avatar(customer, size: 40) %>
  def customer_avatar(customer, size: 40, css: "")
    lead_source_avatar(customer.try(:lead_source), size: size, css: css)
  end

  def lead_source_avatar(source, size: 40, css: "")
    style = lead_source_avatar_style(source)
    icon_px = (size * 0.5).round
    svg = <<~SVG.squish
      <svg xmlns="http://www.w3.org/2000/svg" width="#{icon_px}" height="#{icon_px}"
           viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"
           stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        #{LEAD_SOURCE_ICON_PATHS.fetch(style[:icon], LEAD_SOURCE_ICON_PATHS[:default]).map { |d| %(<path d="#{d}"/>) }.join}
      </svg>
    SVG

    content_tag(:span, raw(svg),
      class: "inline-grid place-items-center shrink-0 #{css}",
      style: "width:#{size}px;height:#{size}px;background:#{style[:bg]};color:#{style[:fg]};",
      title: "Source: #{source.presence || 'Unknown'}")
  end

  # Normalise a lead source into an { icon, fg, bg } style.
  def lead_source_avatar_style(source)
    key =
      case source.to_s
      when /\AODOO/i then :odoo
      when /\ACCR/i then :ccr
      when /\AInbound/i then :inbound
      when "Website" then :website
      when "WA" then :whatsapp
      when "LinkedIn" then :linkedin
      when "Upwork" then :upwork
      when "Email Marketing" then :email
      when "Social Media Platforms" then :social
      when "Web_Summit", "Qatar_Web_summit", "Leap", "Gitex" then :event
      when "Followup" then :followup
      else :default
      end
    LEAD_SOURCE_AVATAR_STYLES[key].merge(icon: key)
  end

  LEAD_SOURCE_AVATAR_STYLES = {
    odoo:     { fg: "#7C3AED", bg: "#EDE9FE" },
    ccr:      { fg: "#059669", bg: "#D1FAE5" },
    inbound:  { fg: "#2563EB", bg: "#DBEAFE" },
    website:  { fg: "#0D9488", bg: "#CCFBF1" },
    whatsapp: { fg: "#16A34A", bg: "#DCFCE7" },
    linkedin: { fg: "#0A66C2", bg: "#DBEAFE" },
    upwork:   { fg: "#15803D", bg: "#DCFCE7" },
    email:    { fg: "#6366F1", bg: "#E0E7FF" },
    social:   { fg: "#DB2777", bg: "#FCE7F3" },
    event:    { fg: "#D97706", bg: "#FEF3C7" },
    followup: { fg: "#475569", bg: "#E2E8F0" },
    default:  { fg: "#475569", bg: "#E2E8F0" }
  }.freeze

  # Heroicons-style outline paths, keyed by source group.
  LEAD_SOURCE_ICON_PATHS = {
    odoo:     ["M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6z", "M13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6z", "M3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25z", "M13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"],
    ccr:      ["M15.75 15.75V18", "M8.25 6h7.5v2.25h-7.5z", "M12 2.25c-1.892 0-3.758.11-5.593.322C5.307 2.7 4.5 3.65 4.5 4.757V19.5a2.25 2.25 0 002.25 2.25h10.5a2.25 2.25 0 002.25-2.25V4.757c0-1.108-.806-2.057-1.907-2.185A48.507 48.507 0 0012 2.25z", "M8.25 12h.008M12 12h.008M15.75 12h.008M8.25 15h.008M12 15h.008"],
    inbound:  ["M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5", "M7.5 12L12 16.5m0 0L16.5 12M12 16.5V3"],
    website:  ["M12 21a9 9 0 100-18 9 9 0 000 18z", "M3.6 9h16.8M3.6 15h16.8", "M12 3a13.5 13.5 0 000 18M12 3a13.5 13.5 0 010 18"],
    whatsapp: ["M21 11.5a8.38 8.38 0 01-8.5 8.25 8.7 8.7 0 01-3.9-.9L3 20l1.2-4.5A8.2 8.2 0 013.5 11.5 8.38 8.38 0 0112 3.25a8.38 8.38 0 019 8.25z", "M8.5 9.5c0 3 2 5 5 5"],
    linkedin: ["M4.5 8.25v10.5M4.5 5.25v.008M9 18.75V12m0 0c0-1.5 1-2.25 2.25-2.25S13.5 10.5 13.5 12v6.75M4.5 18.75H4.5"],
    upwork:   ["M20.25 14.15v4.25a2.18 2.18 0 01-1.872 2.18c-2.087.277-4.216.42-6.378.42s-4.291-.143-6.378-.42A2.18 2.18 0 013.75 18.4v-4.25", "M8.25 6.144V5.25A2.25 2.25 0 0110.5 3h3a2.25 2.25 0 012.25 2.25v.894", "M2.25 9.75a2.18 2.18 0 001.5 2.072A24 24 0 0012 13.5c2.882 0 5.66-.508 8.25-1.428a2.18 2.18 0 001.5-2.072V8.706c0-1.081-.768-2.015-1.837-2.175A48 48 0 0012 6c-2.783 0-5.514.211-8.163.611C2.768 6.771 2 7.705 2.25 8.706z"],
    email:    ["M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75", "M2.25 6.75A2.25 2.25 0 014.5 4.5h15a2.25 2.25 0 012.25 2.25m-19.5 0l8.955 5.51a2.25 2.25 0 002.09 0L21.75 6.75"],
    social:   ["M7.217 10.907a2.25 2.25 0 100 2.186", "M15.75 6.44a2.25 2.25 0 10.001-.001M15.75 17.56a2.25 2.25 0 10.001.001", "M8.7 11.9l6.4-3.6M8.7 12.1l6.4 3.6"],
    event:    ["M16.5 6v.75m0 3v.75m0 3v.75m0 3V18", "M3.375 5.25h17.25c.621 0 1.125.504 1.125 1.125v3.026a3 3 0 000 5.198v3.026c0 .621-.504 1.125-1.125 1.125H3.375c-.621 0-1.125-.504-1.125-1.125v-3.026a3 3 0 000-5.198V6.375c0-.621.504-1.125 1.125-1.125z"],
    followup: ["M16.023 9.348h4.992V4.356", "M2.985 19.644v-4.992h4.992", "M20.015 9.348a8.25 8.25 0 00-13.803-3.7L2.985 9.348M3.985 14.652a8.25 8.25 0 0013.803 3.7l3.227-3.7"],
    default:  ["M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z", "M4.501 20.118a7.5 7.5 0 0114.998 0A17.9 17.9 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"]
  }.freeze
end
