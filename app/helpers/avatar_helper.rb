module AvatarHelper
  # Customer avatar = a branded tile for the lead's SOURCE, so the channel a lead
  # came from is recognisable at a glance. Well-known channels use their real
  # logo (Simple Icons, CC0) on a solid brand-colour tile; the rest use a tinted
  # tile with an outline glyph.
  #
  #   <%= customer_avatar(customer, size: 40) %>
  def customer_avatar(customer, size: 40, css: "")
    lead_source_avatar(customer.try(:lead_source), size: size, css: css)
  end

  def lead_source_avatar(source, size: 40, css: "")
    st = lead_source_avatar_style(source)
    icon_px = (size * (st[:fill] ? 0.56 : 0.52)).round
    stroke_attrs = st[:fill] ? "" : %(stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round")

    svg = <<~SVG.squish
      <svg xmlns="http://www.w3.org/2000/svg" width="#{icon_px}" height="#{icon_px}"
           viewBox="0 0 24 24" fill="#{st[:fill] ? 'currentColor' : 'none'}" #{stroke_attrs} aria-hidden="true">
        #{st[:paths].map { |d| %(<path d="#{d}"/>) }.join}
      </svg>
    SVG

    content_tag(:span, raw(svg),
      class: "inline-grid place-items-center shrink-0 #{css}",
      style: "width:#{size}px;height:#{size}px;background:#{st[:bg]};color:#{st[:fg]};",
      title: "Source: #{source.presence || 'Unknown'}")
  end

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
    LEAD_SOURCE_STYLES[key]
  end

  # Real brand logos (Simple Icons, CC0) on solid brand-colour tiles.
  WHATSAPP_LOGO = "M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z".freeze

  ODOO_LOGO = "M21.1002 15.7957c-1.6015 0-2.8997-1.2983-2.8997-2.8998s1.2983-2.8997 2.8997-2.8997c1.6015 0 2.8998 1.2982 2.8998 2.8997 0 1.5999-1.2979 2.8998-2.8998 2.8998zm0-1.2c.9388.0006 1.7003-.7601 1.7008-1.6989.0004-.9388-.7602-1.7003-1.699-1.7007h-.0018c-.9388.0004-1.6994.7619-1.699 1.7007.0005.9381.761 1.6985 1.699 1.699zm-6.0655 1.2c-1.6014 0-2.8997-1.2983-2.8997-2.8998s1.2983-2.8997 2.8997-2.8997c1.6015 0 2.8998 1.2982 2.8998 2.8997 0 1.5999-1.2999 2.8998-2.8998 2.8998zm0-1.2c.9389.0006 1.7003-.7601 1.7008-1.6989.0005-.9388-.7602-1.7003-1.699-1.7007h-.0018c-.9388.0004-1.6994.7619-1.699 1.7007.0005.9381.761 1.6985 1.699 1.699zM11.865 12.858c0 1.6199-1.2979 2.9378-2.8977 2.9378s-2.8998-1.314-2.8998-2.9358 1.1799-2.8597 2.8998-2.8597c.6359 0 1.2239.134 1.6998.484v-1.68a.6.6 0 0 1 1.2 0v4.0537h-.002zm-2.8977 1.7399c.9388.0005 1.7002-.7602 1.7007-1.699.0005-.9388-.7602-1.7003-1.699-1.7007h-.0017c-.9389.0004-1.6995.7619-1.699 1.7007.0004.9381.7608 1.6985 1.699 1.699zm-6.0675 1.1979C1.2983 15.7957 0 14.4974 0 12.8959s1.2983-2.8997 2.8998-2.8997 2.8997 1.2982 2.8997 2.8997c0 1.5999-1.2999 2.8998-2.8997 2.8998zm0-1.2c.9388.0006 1.7002-.7601 1.7007-1.699.0005-.9387-.7602-1.7002-1.699-1.7006h-.0017c-.9388.0004-1.6995.7619-1.699 1.7007.0004.9381.7608 1.6985 1.699 1.699z".freeze

  # Calculator glyph (Heroicons outline) — CCR = cost-calculator report.
  CALCULATOR_GLYPH = ["M8.25 6h7.5v2.25h-7.5z", "M8.25 12h.008M12 12h.008M15.75 12h.008M8.25 15h.008M12 15h.008M15.75 15V18M8.25 18h.008M12 18h.008", "M6.75 2.25h10.5a1.5 1.5 0 011.5 1.5v16.5a1.5 1.5 0 01-1.5 1.5H6.75a1.5 1.5 0 01-1.5-1.5V3.75a1.5 1.5 0 011.5-1.5z"].freeze

  # Inbox-with-incoming-arrow glyph (Heroicons outline) — inbound leads.
  INBOUND_GLYPH = ["M9 3.75H6.912a2.25 2.25 0 00-2.15 1.588L2.35 13.177a2.25 2.25 0 00-.1.661V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18v-4.162c0-.224-.034-.447-.1-.661L19.24 5.338a2.25 2.25 0 00-2.15-1.588H15", "M2.25 13.5h3.86a2.25 2.25 0 012.012 1.244l.256.512a2.25 2.25 0 002.013 1.244h3.218a2.25 2.25 0 002.013-1.244l.256-.512a2.25 2.25 0 012.013-1.244h3.859", "M12 3v8.25m0 0l-3-3m3 3l3-3"].freeze

  LEAD_SOURCE_STYLES = {
    # brand logos on solid tiles
    odoo:     { bg: "#714B67", fg: "#FFFFFF", fill: true,  paths: [ODOO_LOGO] },
    whatsapp: { bg: "#25D366", fg: "#FFFFFF", fill: true,  paths: [WHATSAPP_LOGO] },
    inbound:  { bg: "#2563EB", fg: "#FFFFFF", fill: false, paths: INBOUND_GLYPH },
    ccr:      { bg: "#059669", fg: "#FFFFFF", fill: false, paths: CALCULATOR_GLYPH },
    # tinted tiles with outline glyphs
    website:  { bg: "#CCFBF1", fg: "#0D9488", fill: false, paths: ["M12 21a9 9 0 100-18 9 9 0 000 18z", "M3.6 9h16.8M3.6 15h16.8", "M12 3a13.5 13.5 0 000 18M12 3a13.5 13.5 0 010 18"] },
    linkedin: { bg: "#DBEAFE", fg: "#0A66C2", fill: false, paths: ["M4.5 8.25v10.5M4.5 5.4v.008M9 18.75V12m0 0c0-1.5 1-2.4 2.25-2.4S13.5 10.5 13.5 12v6.75"] },
    upwork:   { bg: "#DCFCE7", fg: "#15803D", fill: false, paths: ["M20.25 14.15v4.25a2.18 2.18 0 01-1.872 2.18c-2.087.277-4.216.42-6.378.42s-4.291-.143-6.378-.42A2.18 2.18 0 013.75 18.4v-4.25", "M8.25 6.144V5.25A2.25 2.25 0 0110.5 3h3a2.25 2.25 0 012.25 2.25v.894", "M2.25 9.75a2.18 2.18 0 001.5 2.072A24 24 0 0012 13.5c2.882 0 5.66-.508 8.25-1.428a2.18 2.18 0 001.5-2.072V8.706c0-1.081-.768-2.015-1.837-2.175A48 48 0 0012 6c-2.783 0-5.514.211-8.163.611C2.768 6.771 2 7.705 2.25 8.706z"] },
    email:    { bg: "#E0E7FF", fg: "#6366F1", fill: false, paths: ["M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75", "M2.25 6.75A2.25 2.25 0 014.5 4.5h15a2.25 2.25 0 012.25 2.25m-19.5 0l8.955 5.51a2.25 2.25 0 002.09 0L21.75 6.75"] },
    social:   { bg: "#FCE7F3", fg: "#DB2777", fill: false, paths: ["M7.217 10.907a2.25 2.25 0 100 2.186", "M15.75 6.44a2.25 2.25 0 10.001-.001M15.75 17.56a2.25 2.25 0 10.001.001", "M8.7 11.9l6.4-3.6M8.7 12.1l6.4 3.6"] },
    event:    { bg: "#FEF3C7", fg: "#D97706", fill: false, paths: ["M16.5 6v.75m0 3v.75m0 3v.75m0 3V18", "M3.375 5.25h17.25c.621 0 1.125.504 1.125 1.125v3.026a3 3 0 000 5.198v3.026c0 .621-.504 1.125-1.125 1.125H3.375c-.621 0-1.125-.504-1.125-1.125v-3.026a3 3 0 000-5.198V6.375c0-.621.504-1.125 1.125-1.125z"] },
    followup: { bg: "#E2E8F0", fg: "#475569", fill: false, paths: ["M16.023 9.348h4.992V4.356", "M2.985 19.644v-4.992h4.992", "M20.015 9.348a8.25 8.25 0 00-13.803-3.7L2.985 9.348M3.985 14.652a8.25 8.25 0 0013.803 3.7l3.227-3.7"] },
    default:  { bg: "#E2E8F0", fg: "#475569", fill: false, paths: ["M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z", "M4.501 20.118a7.5 7.5 0 0114.998 0A17.9 17.9 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"] }
  }.freeze
end
