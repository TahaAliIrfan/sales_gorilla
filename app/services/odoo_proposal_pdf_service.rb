require 'prawn'
require 'prawn/table'
Prawn::Fonts::AFM.hide_m17n_warning = true

class OdooProposalPdfService
  # ── Brand palette ──────────────────────────────────────────────────────────
  RED       = "E53935"
  RED_DARK  = "B71C1C"
  RED_LIGHT = "FFEBEE"
  INK       = "0D0D0D"   # near-black body text / backgrounds
  DARK      = "1C1C1E"   # slightly lighter dark (cards)
  SLATE     = "1F2937"   # dark section header
  CHARCOAL  = "374151"
  MID       = "6B7280"
  LIGHT     = "F3F4F6"
  BORDER    = "E5E7EB"
  WHITE     = "FFFFFF"
  CREAM     = "FAFAFA"

  # A4 in points
  PW = 595.0
  PH = 841.0
  ML = 42.0   # left/right margin
  CW = PW - ML * 2  # content width

  def initialize(proposal)
    @p    = proposal
    @name = clean(proposal.display_name)
    @date = Date.current.strftime('%d %B %Y')
    @year = Date.current.year
  end

  def generate
    Prawn::Document.new(page_size: 'A4', margin: [0, 0, 0, 0]) do |pdf|
      @pdf = pdf
      @pdf.font 'Helvetica'

      cover
      @pdf.start_new_page; cost_overview
      @pdf.start_new_page; modules_detail
      @pdf.start_new_page; deployment_page
      @pdf.start_new_page; investment_breakdown
      @pdf.start_new_page; next_steps
    end
  end

  private

  # ═══════════════════════════════════════════════════════════════════════════
  # COVER
  # ═══════════════════════════════════════════════════════════════════════════
  def cover
    # White background
    rect 0, PH, PW, PH, WHITE

    # Left red sidebar (full height)
    rect 0, PH, 8, PH, RED

    # Large decorative circle top-right (red tones on white)
    @pdf.fill_color RED_DARK
    @pdf.fill_ellipse [PW + 20, PH + 20], 220, 220

    @pdf.fill_color "FFCDD2"
    @pdf.fill_ellipse [PW - 30, PH - 180], 120, 120

    # ── Odoo ERP text ──────────────────────────────────────────────────────
    color INK
    bold 56, "ODOO ERP", x: 60, y: PH - 80, w: PW - 120

    # Red underline beneath title
    rect 60, PH - 142, 80, 4, RED

    # Subtitle
    color MID
    normal 15, "Implementation Proposal", x: 60, y: PH - 160, w: PW - 120

    # ── Prepared for ───────────────────────────────────────────────────────
    color MID
    bold 8, "PREPARED FOR", x: 60, y: PH - 220, w: 300

    color INK
    bold 30, @name, x: 60, y: PH - 240, w: PW - 120

    # Thin divider
    @pdf.stroke_color "DDDDDD"
    @pdf.line_width 0.5
    @pdf.stroke_line [60, PH - 298], [PW - 60, PH - 298]

    # ── Key numbers on cover ───────────────────────────────────────────────
    stats = [
      { label: "MODULES",     value: @p.selected_modules.size.to_s },
      { label: "USERS",       value: @p.num_users.to_s },
      { label: "DEPLOYMENT",  value: @p.deployment_label }
    ]
    stat_w = (PW - 120) / 3.0
    stats.each_with_index do |s, i|
      x = 60 + i * stat_w
      color MID
      bold 8, s[:label], x: x, y: PH - 322, w: stat_w - 10
      color INK
      bold 16, s[:value], x: x, y: PH - 340, w: stat_w - 10
    end

    # ── Year 1 total highlight box (red on white for contrast) ─────────────
    rect 60, PH - 410, PW - 120, 88, RED_DARK
    rect 60, PH - 410, 4, 88, WHITE

    color "FFCDD2"
    bold 8, "ESTIMATED YEAR 1 INVESTMENT", x: 74, y: PH - 424, w: PW - 160
    color WHITE
    bold 32, "PKR #{fmt(@p.year_1_total)}", x: 74, y: PH - 448, w: PW - 160

    color WHITE
    normal 9, "One-time setup  +  Year 1 Odoo subscription  +  Year 1 hosting",
      x: 74, y: PH - 482, w: PW - 160

    # ── Tecaudex branding (bottom) ─────────────────────────────────────────
    rect 0, 60, PW, 60, "F8F8F8"
    @pdf.stroke_color "E5E7EB"
    @pdf.line_width 0.5
    @pdf.stroke_line [0, 60], [PW, 60]

    color MID
    normal 9, "Prepared by", x: 60, y: 46, w: 100

    color INK
    bold 14, "Tecaudex", x: 60, y: 30, w: 160

    color MID
    normal 9, "Official Odoo Partner", x: 60, y: 14, w: 180

    color MID
    normal 9, "info@tecaudex.pk   |   www.tecaudex.pk   |   #{@date}",
      x: PW - 290, y: 30, w: 245, align: :right

    # red corner accent bottom-right
    rect PW - 8, 60, 8, 60, RED
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PAGE 2 — COST OVERVIEW
  # ═══════════════════════════════════════════════════════════════════════════
  def cost_overview
    header "Cost Overview"

    # ── Three stat boxes ───────────────────────────────────────────────────
    stats = [
      { label: "YEAR 1 TOTAL",        value: "PKR #{fmt(@p.year_1_total)}",              sub: "One-time + Year 1 costs" },
      { label: "MONTHLY (YEAR 2+)",   value: "PKR #{fmt(@p.year_2_recurring_monthly)}",  sub: "Recurring from Year 2" },
      { label: "ONE-TIME SETUP",      value: "PKR #{fmt(@p.implementation_fee.to_i)}",   sub: "Implementation fee" }
    ]

    box_w = CW / 3.0
    y = PH - 128
    stats.each_with_index do |s, i|
      x = ML + i * box_w
      bg = i == 0 ? RED_DARK : LIGHT
      rect x, y, box_w - 4, 72, bg
      rect x, y, 4, 72, RED unless i == 0

      color i == 0 ? "FFCDD2" : MID
      bold 8, s[:label], x: x + 12, y: y - 12, w: box_w - 24
      color i == 0 ? WHITE : INK
      bold 16, s[:value], x: x + 12, y: y - 30, w: box_w - 24
      color i == 0 ? "FFCDD2" : MID
      normal 8, s[:sub], x: x + 12, y: y - 52, w: box_w - 24
    end

    # ── Intro text ─────────────────────────────────────────────────────────
    y2 = PH - 220
    sub_info = @p.odoo_subscription_info
    body "This proposal outlines the full cost of implementing Odoo ERP for #{@name}. " \
         "Costs are split into a one-time Tecaudex implementation fee and a recurring Odoo " \
         "#{sub_info[:plan]} plan subscription billed annually at $#{sub_info[:usd_monthly]}/user/month. " \
         "The Odoo subscription is paid directly to Odoo.",
         y: y2

    # ── Two columns: What's included + Subscription note ──────────────────
    y3 = PH - 296
    col_w = CW / 2.0 - 8

    # Left card
    rect ML, y3, col_w, 170, LIGHT
    rect ML, y3, 4, 170, RED

    color SLATE
    bold 10, "What's Included in Setup Fee", x: ML + 14, y: y3 - 14, w: col_w - 20

    items = [
      "Full configuration of all selected modules",
      "Custom workflows and automation setup",
      "Data migration from existing systems",
      "User onboarding and training sessions",
      "2 weeks post-go-live hypercare support"
    ]
    items.each_with_index do |item, i|
      iy = y3 - 36 - i * 24
      rect ML + 14, iy - 2, 6, 6, RED
      color CHARCOAL
      normal 9, item, x: ML + 28, y: iy + 2, w: col_w - 40
    end

    # Right card
    rx = ML + col_w + 16
    rect rx, y3, col_w, 170, LIGHT
    rect rx, y3, 4, 170, SLATE

    color SLATE
    bold 10, "Odoo Subscription (Paid to Odoo)", x: rx + 14, y: y3 - 14, w: col_w - 20

    sub_info = @p.odoo_subscription_info
    rows = [
      ["Plan",             sub_info[:plan]],
      ["Billing",          "Annual ($#{sub_info[:usd_monthly]}/user/mo)"],
      ["Per User/Month",   "PKR #{fmt(sub_info[:pkr_monthly])}"],
      ["Users",            @p.num_users.to_s],
      ["Monthly Total",    "PKR #{fmt(@p.subscription_monthly_total)}"],
      ["Yearly Total",     "PKR #{fmt(@p.subscription_yearly_total)}"]
    ]
    rows.each_with_index do |(k, v), i|
      ry = y3 - 36 - i * 24
      color MID
      normal 9, k, x: rx + 14, y: ry + 2, w: 100
      color CHARCOAL
      bold 9, v, x: rx + 124, y: ry + 2, w: col_w - 134
    end

    footer
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PAGE 3 — MODULES
  # ═══════════════════════════════════════════════════════════════════════════
  def modules_detail
    header "Selected Modules"

    mods = @p.selected_module_details
    body "#{mods.size} module#{mods.size == 1 ? '' : 's'} selected — each is fully " \
         "configured and integrated as part of the one-time implementation fee.",
         y: PH - 128

    card_h = 54
    gap    = 6
    col_w  = (CW - gap) / 2.0
    y_start = PH - 168

    # Track position independently to handle overflow
    page_y   = y_start
    col      = 0

    mods.each_with_index do |mod, i|
      x = ML + col * (col_w + gap)

      # Page overflow
      if page_y - card_h < 60
        footer
        @pdf.start_new_page
        header "Selected Modules (cont.)"
        page_y = PH - 128
        col    = 0
        x      = ML
      end

      # Card
      rect x, page_y, col_w, card_h, CREAM
      rect x, page_y, 3, card_h, RED

      # Module name + cost
      color INK
      bold 11, clean(mod[:label]), x: x + 12, y: page_y - 12, w: col_w - 130

      rect x + col_w - 96, page_y - 8, 88, 20, RED_DARK
      color WHITE
      bold 8, "PKR #{fmt(mod[:impl_cost])}", x: x + col_w - 94, y: page_y - 12, w: 84, align: :center

      # Description
      color MID
      normal 9, clean(mod[:description]), x: x + 12, y: page_y - 30, w: col_w - 20, h: 22

      col += 1
      if col == 2
        col    = 0
        page_y -= (card_h + gap)
      end
    end

    # Odd module — advance row
    page_y -= (card_h + gap) if col == 1

    # Total bar
    total_y = [page_y - 10, 72].max
    rect ML, total_y, CW, 34, RED_DARK
    color WHITE
    bold 11, "Total Implementation Fee (One-time)", x: ML + 14, y: total_y - 10, w: CW - 200
    bold 14, "PKR #{fmt(@p.implementation_fee.to_i)}", x: ML + 14, y: total_y - 10, w: CW - 20, align: :right

    footer
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PAGE 4 — DEPLOYMENT & HOSTING
  # ═══════════════════════════════════════════════════════════════════════════
  def deployment_page
    header "Deployment & Hosting"

    dtype  = @p.deployment_type
    dlabel = @p.deployment_label
    users  = @p.num_users

    y = PH - 128
    body "#{@name} has chosen #{dlabel} for #{users} user#{users == 1 ? '' : 's'}. " \
         "Below are the infrastructure details and a side-by-side comparison.",
         y: y
    y -= 50

    # Selected deployment card (full width)
    rect ML, y, CW, 60, LIGHT
    rect ML, y, 5, 60, RED
    color INK
    bold 16, dlabel, x: ML + 18, y: y - 14, w: CW - 180
    desc = {
      'online'     => "Fully managed SaaS by Odoo. Odoo handles all upgrades, backups and security. No server to manage.",
      'sh'         => "Odoo.sh: managed cloud with Git deployment, staging branches and full developer access.",
      'on_premise' => "Self-hosted on Tecaudex-managed AWS infrastructure. Full data sovereignty and custom integrations."
    }[dtype]
    color MID
    normal 9, desc, x: ML + 18, y: y - 36, w: CW - 26

    # hosting cost on right of this card (SH or On-Premise)
    if @p.current_tier_info
      color RED_DARK
      bold 10, "PKR #{fmt(@p.hosting_monthly)}/mo",  x: ML + 18, y: y - 14, w: CW - 26, align: :right
      color MID
      normal 8, "PKR #{fmt(@p.hosting_yearly)}/yr",  x: ML + 18, y: y - 28, w: CW - 26, align: :right
    end

    y -= 78

    # ── Comparison table ───────────────────────────────────────────────────
    section_label "Deployment Comparison", y: y
    y -= 16

    c0 = CW * 0.30
    c1 = CW * 0.235
    c2 = CW * 0.235
    c3 = CW * 0.23
    col_ws = [c0, c1, c2, c3]
    heads  = ["Feature", "Odoo Online", "Odoo.sh", "On-Premise"]
    rows   = [
      ["Odoo Plan",        "Standard",      "Custom",          "Custom"],
      ["License/User/Mo",  "$7.25 (annual)","$10.90 (annual)", "$10.90 (annual)"],
      ["Odoo Studio",      "No",            "Yes",             "Yes"],
      ["Multi-Company",    "No",            "Yes",             "Yes"],
      ["External API",     "No",            "Yes",             "Yes"],
      ["Data Location",    "Odoo servers",  "Odoo / GitHub",   "Your servers"],
      ["Platform Cost",    "Included",      "Extra (workers)", "Hosting required"],
      ["Best For",         "SMBs / start",  "Dev teams",       "Enterprise"]
    ]
    hi_col = dtype == 'online' ? 1 : (dtype == 'sh' ? 2 : 3)

    # Header row
    draw_table_row heads, col_ws, y, row_h: 22, header: true, hi_col: hi_col
    rows.each_with_index do |row, ri|
      draw_table_row row, col_ws, y - 22 - ri * 20, row_h: 20,
        header: false, hi_col: hi_col, alt: ri.odd?
    end

    ty = y - 22 - rows.size * 20 - 24

    # ── Hosting / SH tier card ─────────────────────────────────────────────
    if (tier = @p.current_tier_info)
      tier_label = dtype == 'sh' ? "Odoo.sh Platform Plan" : "Selected Hosting Tier"
      tier_note  = dtype == 'sh' ? "Odoo.sh worker-based infrastructure managed by Odoo." \
                                 : "Based on AWS EC2 estimates. Actual cost may vary."
      section_label tier_label, y: ty
      ty -= 16

      rect ML, ty, CW, 62, LIGHT
      rect ML, ty, 4, 62, RED

      color SLATE
      bold 14, tier[:label], x: ML + 16, y: ty - 14, w: 160

      color MID
      normal 9, tier[:specs], x: ML + 16, y: ty - 32, w: 260
      normal 9, tier[:users], x: ML + 16, y: ty - 46, w: 260
      normal 8, tier_note,    x: ML + 16, y: ty - 58, w: 280

      color RED_DARK
      bold 16, "PKR #{fmt(tier[:annual_pkr])}/yr",
        x: ML + 16, y: ty - 22, w: CW - 26, align: :right
      color MID
      normal 10, "PKR #{fmt(tier[:monthly_pkr])}/mo",
        x: ML + 16, y: ty - 40, w: CW - 26, align: :right
    end

    footer
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PAGE 5 — INVESTMENT BREAKDOWN
  # ═══════════════════════════════════════════════════════════════════════════
  def investment_breakdown
    header "Investment Breakdown"

    body "Full itemised cost breakdown — one-time setup costs and ongoing subscription " \
         "fees for #{@name}.",
         y: PH - 128

    y = PH - 172

    # ── Section A: One-time Costs ──────────────────────────────────────────
    section_label "A  One-Time Implementation Costs", y: y, underline: false
    y -= 16

    # Table header
    cw = [CW * 0.38, CW * 0.34, CW * 0.28]
    draw_table_row(["Module / Component", "Description", "Amount (PKR)"],
      cw, y, row_h: 22, header: true, hi_col: nil)

    @p.selected_module_details.each_with_index do |mod, i|
      draw_table_row(
        [clean(mod[:label]), "Setup & Configuration", fmt(mod[:impl_cost])],
        cw, y - 22 - i * 19, row_h: 19, hi_col: nil, alt: i.odd?,
        align_last: :right
      )
    end

    sub_y = y - 22 - @p.selected_module_details.size * 19
    subtotal_row "Implementation Subtotal", @p.implementation_fee.to_i, sub_y
    y = sub_y - 28

    # ── Section B: Recurring Costs ─────────────────────────────────────────
    section_label "B  Recurring Costs  (Monthly & Yearly)", y: y, underline: false
    y -= 16

    rcw = [CW * 0.36, CW * 0.22, CW * 0.21, CW * 0.21]
    draw_table_row(["Item", "Basis", "Monthly (PKR)", "Yearly (PKR)"],
      rcw, y, row_h: 22, header: true, hi_col: nil)

    sub_info = @p.odoo_subscription_info
    recur_rows = [
      [
        "Odoo Subscription",
        "#{@p.num_users} users × PKR #{fmt(sub_info[:pkr_monthly])}/mo",
        fmt(@p.subscription_monthly_total),
        fmt(@p.subscription_yearly_total)
      ]
    ]

    if @p.hosting_monthly > 0
      tier_info  = @p.current_tier_info
      host_label = @p.deployment_type == 'sh' \
                     ? "Odoo.sh Platform (#{tier_info&.dig(:label)})" \
                     : "Server Hosting (#{tier_info&.dig(:label)})"
      recur_rows << [
        host_label,
        tier_info&.dig(:specs).to_s,
        fmt(@p.hosting_monthly),
        fmt(@p.hosting_yearly)
      ]
    end

    recur_rows.each_with_index do |row, i|
      draw_table_row(row, rcw, y - 22 - i * 19, row_h: 19,
        hi_col: nil, alt: i.odd?, align_last: :right)
    end

    recur_sub_y = y - 22 - recur_rows.size * 19
    subtotal_row(
      "Recurring Subtotal",
      @p.year_2_recurring_yearly,
      recur_sub_y,
      extra_label: "PKR #{fmt(@p.year_2_recurring_monthly)}/mo"
    )
    y = recur_sub_y - 36

    # ── Year Comparison ────────────────────────────────────────────────────
    section_label "C  Year-on-Year Cost Summary", y: y, underline: false
    y -= 16

    ycw = [CW * 0.40, CW * 0.30, CW * 0.30]
    draw_table_row ["Cost Item", "Year 1", "Year 2 onwards"],
      ycw, y, row_h: 22, header: true, hi_col: nil

    hosting_yr_label = @p.deployment_type == 'sh' ? "Odoo.sh Platform" : "Server Hosting"
    year_rows = [
      ["Implementation Fee (one-time)", fmt(@p.implementation_fee.to_i), "—"],
      ["Odoo Subscription",             fmt(@p.subscription_yearly_total), fmt(@p.subscription_yearly_total)],
      [hosting_yr_label,                fmt(@p.hosting_yearly), fmt(@p.hosting_yearly)]
    ]
    year_rows.each_with_index do |row, i|
      draw_table_row row, ycw, y - 22 - i * 20, row_h: 20,
        hi_col: nil, alt: i.odd?, align_last: :right
    end

    # Grand total row — Year 1 vs Year 2
    grand_y = y - 22 - year_rows.size * 20
    rect ML, grand_y, CW, 32, RED_DARK
    color WHITE
    bold 11, "GRAND TOTAL", x: ML + 12, y: grand_y - 10, w: ycw[0] - 10
    bold 13, "PKR #{fmt(@p.year_1_total)}",
      x: ML + ycw[0], y: grand_y - 10, w: ycw[1] - 6, align: :center
    bold 13, "PKR #{fmt(@p.year_2_recurring_yearly)}",
      x: ML + ycw[0] + ycw[1], y: grand_y - 10, w: ycw[2] - 6, align: :center

    color "FFCDD2"
    normal 8, "(one-time + year 1 recurring)",
      x: ML + ycw[0], y: grand_y - 24, w: ycw[1] - 6, align: :center
    normal 8, "per year",
      x: ML + ycw[0] + ycw[1], y: grand_y - 24, w: ycw[2] - 6, align: :center

    footer
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PAGE 6 — NEXT STEPS
  # ═══════════════════════════════════════════════════════════════════════════
  def next_steps
    header "Next Steps"

    body "We are excited to partner with #{@name} on this Odoo ERP implementation. " \
         "Here is the recommended path forward:",
         y: PH - 128

    steps = [
      ["01", "Proposal Review",      "This week",  "Share this with your team. We are available to present in person or virtually."],
      ["02", "Discovery Workshop",   "Week 1–2",   "A structured session to finalise scope, map workflows and agree on timeline."],
      ["03", "Agreement & Kickoff",  "Week 2–3",   "Sign the service agreement and launch with your dedicated project manager."],
      ["04", "Implementation",        "Weeks 4–10", "Configuration, customisation, data migration and integrations with weekly updates."],
      ["05", "Training & Go-Live",   "Week 10–11", "Hands-on training, UAT sign-off and go-live on the agreed date."],
      ["06", "Post-Go-Live Support", "2 weeks",    "Dedicated hypercare — rapid resolution of any issues after launch."]
    ]

    y = PH - 196
    steps.each do |num, title, time, desc|
      rect ML,      y, 42, 50, RED_DARK
      rect ML,      y, 42, 4,  RED
      rect ML + 42, y, CW - 42, 50, CREAM

      # Number
      color WHITE
      bold 16, num, x: ML + 4, y: y - 16, w: 34, align: :center

      # Title
      color SLATE
      bold 11, title, x: ML + 56, y: y - 12, w: CW - 200

      # Time badge
      rect ML + CW - 96, y - 8, 88, 18, LIGHT
      color RED_DARK
      bold 8, time, x: ML + CW - 94, y: y - 12, w: 84, align: :center

      # Description
      color MID
      normal 9, desc, x: ML + 56, y: y - 30, w: CW - 170, h: 20

      # Border line between steps
      @pdf.stroke_color BORDER
      @pdf.line_width 0.4
      @pdf.stroke_line [ML, y - 50], [ML + CW, y - 50]

      y -= 54
    end

    # CTA block
    y -= 8
    rect ML, y, CW, 60, SLATE
    rect ML, y, 5, 60, RED

    color WHITE
    bold 15, "Ready to get started?", x: ML + 18, y: y - 14, w: CW - 36
    color "94A3B8"
    normal 10, "info@tecaudex.pk   |   www.tecaudex.pk   |   Tecaudex, Pakistan",
      x: ML + 18, y: y - 34, w: CW - 36
    color "6B7280"
    normal 9, "#{@year} Tecaudex. All rights reserved. This proposal is confidential.",
      x: ML + 18, y: y - 50, w: CW - 36

    footer
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # LAYOUT HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  def header(title)
    rect 0, PH, PW, 82, WHITE
    rect 0, PH, 5, 82, RED

    color INK
    bold 22, title, x: 20, y: PH - 24, w: PW - 240

    color MID
    normal 8, "Prepared for #{@name}", x: PW - 230, y: PH - 28, w: 218, align: :right
    normal 8, @date, x: PW - 230, y: PH - 42, w: 218, align: :right

    @pdf.stroke_color BORDER
    @pdf.line_width 0.8
    @pdf.stroke_line [0, PH - 82], [PW, PH - 82]

    # Red accent line under title
    @pdf.stroke_color RED
    @pdf.line_width 2
    @pdf.stroke_line [5, PH - 82], [80, PH - 82]
  end

  def footer
    rect 0, 30, PW, 30, LIGHT
    rect 0, 30, 4, 30, RED
    color MID
    normal 8, "Tecaudex  |  Official Odoo Partner  |  www.tecaudex.pk",
      x: 14, y: 22, w: PW / 2
    normal 8, "Odoo ERP Proposal  |  #{@name}",
      x: PW / 2, y: 22, w: PW / 2 - 14, align: :right
  end

  def section_label(text, y:, underline: false)
    color RED
    bold 10, text, x: ML, y: y, w: CW
    if underline
      @pdf.stroke_color RED
      @pdf.line_width 0.5
      @pdf.stroke_line [ML, y - 6], [ML + CW, y - 6]
    end
  end

  def body(text, y:)
    color CHARCOAL
    normal 10, text, x: ML, y: y, w: CW, leading: 4
  end

  # Generic table row (Prawn manual positioning — no prawn/table dependency)
  def draw_table_row(cells, col_ws, y, row_h:, header: false, hi_col: nil, alt: false, align_last: :left)
    x = ML
    cells.each_with_index do |cell, ci|
      cw = col_ws[ci]

      # Background
      bg = if header
        RED_DARK
      elsif hi_col && ci == hi_col
        RED_LIGHT
      elsif alt
        LIGHT
      else
        WHITE
      end
      rect x, y, cw, row_h, bg

      # Cell border
      @pdf.stroke_color BORDER
      @pdf.line_width 0.3
      @pdf.stroke_rectangle [x, y], cw, row_h

      # Text
      if header
        color WHITE
        bold 9, cell, x: x + 6, y: y - (row_h == 22 ? 7 : 5), w: cw - 10,
          align: (ci == cells.size - 1 ? :right : :left)
      else
        if hi_col && ci == hi_col
          color RED_DARK
          bold 9, cell, x: x + 6, y: y - 5, w: cw - 10,
            align: (ci == cells.size - 1 ? (align_last || :left) : :left)
        else
          color ci == 0 ? CHARCOAL : MID
          sty = ci == 0 ? :bold : :normal
          send(sty, 9, cell, x: x + 6, y: y - 5, w: cw - 10,
            align: (ci == cells.size - 1 ? (align_last || :left) : :left))
        end
      end

      x += cw
    end
  end

  def subtotal_row(label, amount, y, extra_label: nil)
    rect ML, y, CW, 26, BORDER
    rect ML, y, 4, 26, RED

    color MID
    bold 9, label, x: ML + 12, y: y - 8, w: CW - 200

    color INK
    bold 11, "PKR #{fmt(amount)}", x: ML + 12, y: y - 8, w: CW - 20, align: :right

    if extra_label
      color MID
      normal 8, extra_label, x: ML + 12, y: y - 20, w: CW - 20, align: :right
    end
  end

  # ── Text primitives ────────────────────────────────────────────────────────

  def bold(size, text, x:, y:, w:, align: :left, h: nil)
    opts = { at: [x, y], width: w, align: align }
    opts[:height] = h if h
    @pdf.fill_color @_color || "000000"
    @pdf.font_size  size
    @pdf.font 'Helvetica', style: :bold
    @pdf.text_box clean(text), **opts
  end

  def normal(size, text, x:, y:, w:, align: :left, leading: 0, h: nil)
    opts = { at: [x, y], width: w, align: align, leading: leading }
    opts[:height] = h if h
    @pdf.fill_color @_color || "000000"
    @pdf.font_size  size
    @pdf.font 'Helvetica', style: :normal
    @pdf.text_box clean(text), **opts
  end

  def color(hex)
    @_color = hex
    @pdf.fill_color hex
  end

  # Solid rectangle — top-left origin style (y is the top edge)
  def rect(x, top_y, w, h, hex)
    @pdf.fill_color hex
    @pdf.fill_rectangle [x, top_y], w, h
  end

  def fmt(n)
    n.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  end

  def clean(text)
    text.to_s
        .gsub(/["""]/, '"').gsub(/[''']/, "'")
        .gsub(/[–—]/, '-').gsub(/…/, '...')
        .gsub(/[^\x00-\x7F]/, '').strip
  end
end
