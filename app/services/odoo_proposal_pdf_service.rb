require 'prawn'
require 'prawn/table'

Prawn::Fonts::AFM.hide_m17n_warning = true

class OdooProposalPdfService
  # Tecaudex brand colours — Red & Black
  RED        = "E53935"
  RED_DARK   = "B71C1C"
  RED_LIGHT  = "FFEBEE"
  BLACK      = "111111"
  CHARCOAL   = "1F2937"
  DARK_GRAY  = "374151"
  GRAY       = "6B7280"
  LIGHT_GRAY = "F3F4F6"
  BORDER     = "E5E7EB"
  WHITE      = "FFFFFF"

  # A4 page dimensions (pts at 72dpi)
  PAGE_W = 595.0
  PAGE_H = 841.0
  MARGIN = 45.0

  def initialize(proposal)
    @proposal = proposal
    @client   = clean(proposal.display_name)
    @date     = Date.current.strftime('%B %d, %Y')
    @year     = Date.current.year
  end

  def generate
    Prawn::Document.new(page_size: 'A4', margin: [0, 0, 0, 0]) do |pdf|
      @pdf = pdf
      @pdf.font 'Helvetica'

      cover_page
      @pdf.start_new_page; table_of_contents
      @pdf.start_new_page; executive_summary
      @pdf.start_new_page; modules_page
      @pdf.start_new_page; deployment_and_hosting
      @pdf.start_new_page; investment_summary
      @pdf.start_new_page; next_steps_page
    end
  end

  private

  # ─── COVER PAGE ────────────────────────────────────────────────────────────
  def cover_page
    # Black full-page background
    fill_rect 0, PAGE_H, PAGE_W, PAGE_H, BLACK

    # Red top bar (full width, 180pt tall)
    fill_rect 0, PAGE_H, PAGE_W, 180, RED

    # White diagonal accent stripe on right side of red bar
    fill_rect PAGE_W - 6, PAGE_H, 6, PAGE_H, RED_DARK

    # "ODOO ERP" large title in white over red bar
    @pdf.fill_color WHITE
    @pdf.font_size 44
    @pdf.font 'Helvetica', style: :bold
    @pdf.text_box 'ODOO ERP',
      at: [MARGIN, PAGE_H - 40],
      width: PAGE_W - MARGIN * 2

    # "Implementation Proposal" subtitle in red bar
    @pdf.fill_color "FFCDD2"
    @pdf.font_size 18
    @pdf.font 'Helvetica', style: :normal
    @pdf.text_box 'Implementation Proposal',
      at: [MARGIN, PAGE_H - 100],
      width: PAGE_W - MARGIN * 2

    # Thin white divider below red bar
    @pdf.stroke_color WHITE
    @pdf.line_width 0.5
    @pdf.stroke_line [MARGIN, PAGE_H - 188], [PAGE_W - MARGIN, PAGE_H - 188]

    # PREPARED FOR label
    @pdf.fill_color "FFCDD2"
    @pdf.font_size 9
    @pdf.font 'Helvetica', style: :normal
    @pdf.text_box 'PREPARED FOR',
      at: [MARGIN, PAGE_H - 215],
      width: PAGE_W - MARGIN * 2

    # Client name in white, large
    @pdf.fill_color WHITE
    @pdf.font_size 28
    @pdf.font 'Helvetica', style: :bold
    @pdf.text_box @client,
      at: [MARGIN, PAGE_H - 235],
      width: PAGE_W - MARGIN * 2,
      size: 28

    # Horizontal divider mid-page
    @pdf.stroke_color RED
    @pdf.line_width 1
    @pdf.stroke_line [MARGIN, PAGE_H - 340], [PAGE_W - MARGIN, PAGE_H - 340]

    # What's in this proposal
    @pdf.fill_color "9CA3AF"
    @pdf.font_size 10
    @pdf.font 'Helvetica', style: :normal
    @pdf.text_box 'This proposal covers:',
      at: [MARGIN, PAGE_H - 360],
      width: PAGE_W / 2

    covers = [
      'Selected Odoo Modules & Implementation Plan',
      'Deployment & Hosting Architecture',
      'Transparent Investment Breakdown',
      'Implementation Timeline & Next Steps'
    ]
    covers.each_with_index do |item, i|
      @pdf.fill_color RED
      fill_rect MARGIN, PAGE_H - 380 - i * 22 + 8, 6, 6, RED
      @pdf.fill_color "D1D5DB"
      @pdf.font_size 10
      @pdf.text_box item,
        at: [MARGIN + 14, PAGE_H - 376 - i * 22],
        width: PAGE_W / 2 - 20
    end

    # Prepared by block (bottom-left)
    @pdf.fill_color "374151"
    fill_rect MARGIN, 130, PAGE_W / 2 - MARGIN, 90, "1F2937"

    @pdf.fill_color "9CA3AF"
    @pdf.font_size 9
    @pdf.text_box 'PREPARED BY',
      at: [MARGIN + 14, 122],
      width: PAGE_W / 2 - MARGIN - 20

    @pdf.fill_color WHITE
    @pdf.font_size 16
    @pdf.font 'Helvetica', style: :bold
    @pdf.text_box 'Tecaudex',
      at: [MARGIN + 14, 108],
      width: PAGE_W / 2 - MARGIN - 20

    @pdf.fill_color "9CA3AF"
    @pdf.font_size 9
    @pdf.font 'Helvetica', style: :normal
    @pdf.text_box 'Official Odoo Partner',
      at: [MARGIN + 14, 90],
      width: PAGE_W / 2 - MARGIN - 20

    @pdf.fill_color "6B7280"
    @pdf.font_size 8
    @pdf.text_box 'info@tecaudex.pk  |  www.tecaudex.pk',
      at: [MARGIN + 14, 75],
      width: PAGE_W / 2 - MARGIN - 20

    # Date (bottom-right)
    @pdf.fill_color "6B7280"
    @pdf.font_size 9
    @pdf.text_box @date,
      at: [PAGE_W / 2, 108],
      width: PAGE_W / 2 - MARGIN,
      align: :right

    @pdf.fill_color RED
    @pdf.font_size 9
    @pdf.text_box "Confidential",
      at: [PAGE_W / 2, 90],
      width: PAGE_W / 2 - MARGIN,
      align: :right

    # Bottom red accent bar
    fill_rect 0, 30, PAGE_W, 4, RED
  end

  # ─── TABLE OF CONTENTS ─────────────────────────────────────────────────────
  def table_of_contents
    page_header 'Table of Contents'

    sections = [
      ['01', 'Executive Summary',   'Overview of the opportunity and Tecaudex approach'],
      ['02', 'Selected Modules',    'Odoo apps included in this proposal'],
      ['03', 'Deployment & Hosting','Infrastructure, hosting tiers and access model'],
      ['04', 'Investment Summary',  'Transparent and itemised cost breakdown'],
      ['05', 'Next Steps',          'Timeline for moving forward together']
    ]

    y = PAGE_H - 140
    sections.each_with_index do |(num, title, sub), i|
      # Alternating row background
      fill_rect MARGIN, y + 14, PAGE_W - MARGIN * 2, 38, i.even? ? LIGHT_GRAY : WHITE

      # Red number
      @pdf.fill_color RED
      @pdf.font_size 14
      @pdf.font 'Helvetica', style: :bold
      @pdf.text_box num, at: [MARGIN + 12, y + 24], width: 28

      # Title
      @pdf.fill_color CHARCOAL
      @pdf.font_size 12
      @pdf.text_box title, at: [MARGIN + 50, y + 24], width: PAGE_W - MARGIN * 2 - 120

      # Subtitle
      @pdf.fill_color GRAY
      @pdf.font_size 9
      @pdf.font 'Helvetica', style: :normal
      @pdf.text_box sub, at: [MARGIN + 50, y + 10], width: PAGE_W - MARGIN * 2 - 100

      # Dotted separator
      @pdf.stroke_color BORDER
      @pdf.line_width 0.5
      @pdf.dash 2, space: 3
      @pdf.stroke_line [MARGIN, y - 4], [PAGE_W - MARGIN, y - 4]
      @pdf.undash

      y -= 46
    end

    page_footer
  end

  # ─── EXECUTIVE SUMMARY ─────────────────────────────────────────────────────
  def executive_summary
    page_header 'Executive Summary'

    y = PAGE_H - 140
    intro = "This proposal outlines a tailored Odoo ERP implementation designed " \
            "specifically for #{@client}. Tecaudex, as an official Odoo partner, " \
            "brings proven delivery methodology and deep technical expertise to ensure " \
            "a smooth deployment that drives measurable business value from day one."
    y = body_text(intro, y: y)
    y -= 20

    # Three value pillars
    pillars = [
      { title: 'Rapid Delivery',       desc: 'Structured 4-phase approach minimises disruption and accelerates time-to-value.' },
      { title: 'Official Odoo Partner', desc: 'Direct partner access to Odoo ecosystem, priority support and latest features.' },
      { title: 'Custom-fit Solution',   desc: 'Every workflow, report and automation configured to match your exact needs.' }
    ]

    col_w  = (PAGE_W - MARGIN * 2 - 16) / 3.0
    card_h = 80

    pillars.each_with_index do |p, i|
      x = MARGIN + i * (col_w + 8)

      # Card background
      fill_rect x, y, col_w, card_h, LIGHT_GRAY

      # Red top accent bar
      fill_rect x, y, col_w, 4, RED

      # Title
      @pdf.fill_color CHARCOAL
      @pdf.font_size 11
      @pdf.font 'Helvetica', style: :bold
      @pdf.text_box p[:title],
        at: [x + 10, y - 12],
        width: col_w - 20

      # Description
      @pdf.fill_color GRAY
      @pdf.font_size 9
      @pdf.font 'Helvetica', style: :normal
      @pdf.text_box p[:desc],
        at: [x + 10, y - 28],
        width: col_w - 20,
        height: 44,
        leading: 3
    end

    y -= card_h + 26
    section_title 'Why Odoo ERP?', y: y
    y -= 22

    bullets = [
      "World's most used open-source ERP — 12 million+ users in 160+ countries",
      'Modular architecture: start with what you need, expand as you grow',
      'Single unified platform replacing disconnected spreadsheets and tools',
      'Annual releases delivering new features, security patches and performance',
      'Available as fully managed SaaS, cloud-hosted, or on-premise'
    ]

    bullets.each do |b|
      # Red bullet dot
      fill_rect MARGIN + 2, y - 2, 6, 6, RED

      @pdf.fill_color DARK_GRAY
      @pdf.font_size 10
      @pdf.text_box b,
        at: [MARGIN + 16, y + 2],
        width: PAGE_W - MARGIN * 2 - 20
      y -= 18
    end

    page_footer
  end

  # ─── MODULES PAGE ──────────────────────────────────────────────────────────
  def modules_page
    page_header 'Selected Modules'

    mods = @proposal.selected_module_details

    intro = "The following #{mods.size} Odoo module#{mods.size == 1 ? '' : 's'} have been " \
            "selected to address #{@client}'s core requirements. Each module is fully " \
            "configured and integrated during implementation."
    y = PAGE_H - 140
    y = body_text(intro, y: y)
    y -= 16

    col_w  = (PAGE_W - MARGIN * 2 - 10) / 2.0
    card_h = 56
    row_h  = card_h + 8
    page_row = 0   # tracks row on current page

    mods.each_with_index do |mod, i|
      col     = i % 2
      page_row = i / 2 if i < 2  # set initial page_row

      x = MARGIN + col * (col_w + 10)
      card_y = y - page_row * row_h

      # Overflow to next page
      if card_y - card_h < 60
        page_footer
        @pdf.start_new_page
        page_header 'Selected Modules (continued)'
        y = PAGE_H - 140
        page_row = 0
        card_y = y
      end

      # Track page_row separately from global i
      page_row = (card_y == y ? 0 : (y - card_y) / row_h) if col == 0 && i > 0

      # Card
      fill_rect x, card_y, col_w, card_h, LIGHT_GRAY

      # Red left border
      fill_rect x, card_y, 4, card_h, RED

      # Module name
      @pdf.fill_color CHARCOAL
      @pdf.font_size 11
      @pdf.font 'Helvetica', style: :bold
      @pdf.text_box clean(mod[:label]),
        at: [x + 14, card_y - 10],
        width: col_w - 100

      # Cost pill
      fill_rect x + col_w - 85, card_y - 8, 78, 18, RED_DARK
      @pdf.fill_color WHITE
      @pdf.font_size 8
      @pdf.font 'Helvetica', style: :bold
      @pdf.text_box "PKR #{number(mod[:impl_cost])}",
        at: [x + col_w - 84, card_y - 12],
        width: 76,
        align: :center

      # Description
      @pdf.fill_color GRAY
      @pdf.font_size 9
      @pdf.font 'Helvetica', style: :normal
      @pdf.text_box clean(mod[:description]),
        at: [x + 14, card_y - 28],
        width: col_w - 24,
        height: 26,
        leading: 3

      # Advance page_row after placing right-column card (or single last card)
      page_row += 1 if col == 1 || i == mods.size - 1
    end

    # Total bar at bottom of last card
    last_row   = page_row
    total_y    = y - last_row * row_h - 10
    total_y    = 80 if total_y < 80

    fill_rect MARGIN, total_y, PAGE_W - MARGIN * 2, 34, RED_DARK

    @pdf.fill_color WHITE
    @pdf.font_size 11
    @pdf.font 'Helvetica', style: :bold
    @pdf.text_box 'Total Implementation Fee',
      at: [MARGIN + 14, total_y - 8],
      width: PAGE_W - MARGIN * 2 - 160

    @pdf.font_size 13
    @pdf.text_box "PKR #{number(@proposal.implementation_fee.to_i)}",
      at: [PAGE_W - MARGIN - 155, total_y - 8],
      width: 150,
      align: :right

    page_footer
  end

  # ─── DEPLOYMENT & HOSTING ──────────────────────────────────────────────────
  def deployment_and_hosting
    page_header 'Deployment & Hosting'

    deploy_type  = @proposal.deployment_type
    deploy_label = @proposal.deployment_label
    num_users    = @proposal.num_users

    y = PAGE_H - 140
    intro = "#{@client} has selected the #{deploy_label} deployment with #{num_users} " \
            "user#{num_users == 1 ? '' : 's'}. Below is a summary of the infrastructure, " \
            "access model and support responsibilities."
    y = body_text(intro, y: y)
    y -= 18

    # Selected deployment highlight card
    fill_rect MARGIN, y, PAGE_W - MARGIN * 2, 52, RED_DARK

    @pdf.fill_color WHITE
    @pdf.font_size 16
    @pdf.font 'Helvetica', style: :bold
    @pdf.text_box deploy_label,
      at: [MARGIN + 16, y - 12],
      width: PAGE_W - MARGIN * 2 - 32

    descriptor = case deploy_type
    when 'online'
      'Fully managed SaaS hosted by Odoo — zero server management, auto upgrades and backups included.'
    when 'sh'
      'Odoo.sh managed cloud with full Git integration, staging branches and developer tooling.'
    when 'on_premise'
      'Self-hosted on Tecaudex-managed infrastructure — full data sovereignty, custom integrations and on-site access.'
    end

    @pdf.fill_color "FFCDD2"
    @pdf.font_size 9
    @pdf.font 'Helvetica', style: :normal
    @pdf.text_box descriptor,
      at: [MARGIN + 16, y - 32],
      width: PAGE_W - MARGIN * 2 - 32

    y -= 70
    section_title 'Deployment Comparison', y: y
    y -= 18

    # Comparison table — 4 equal columns
    rows = [
      ['Feature',          'Odoo Online',  'Odoo.sh',        'On-Premise'],
      ['Managed Updates',  'Automatic',    'Configurable',   'Manual'],
      ['Custom Modules',   'No',           'Yes',            'Yes'],
      ['Data Location',    'Odoo servers', 'GitHub / Odoo',  'Your servers'],
      ['Scaling',          'Odoo plans',   'Flexible tiers', 'Unlimited'],
      ['Best For',         'Small teams',  'Dev teams',      'Enterprise']
    ]
    highlight_col = deploy_type == 'online' ? 1 : (deploy_type == 'sh' ? 2 : 3)
    col_w_table   = (PAGE_W - MARGIN * 2) / 4.0

    rows.each_with_index do |row, ri|
      row_h_table = ri == 0 ? 22 : 20
      row_y = y - ri * 20

      row.each_with_index do |cell, ci|
        cx = MARGIN + ci * col_w_table

        if ri == 0
          fill_rect cx, row_y, col_w_table, 22, RED_DARK
          @pdf.fill_color WHITE
          @pdf.font_size 9
          @pdf.font 'Helvetica', style: :bold
        else
          is_hi = (ci == highlight_col)
          fill_rect cx, row_y, col_w_table, 20, is_hi ? RED_LIGHT : (ri.odd? ? LIGHT_GRAY : WHITE)
          @pdf.fill_color is_hi ? RED_DARK : (ci == 0 ? CHARCOAL : GRAY)
          @pdf.font_size 9
          @pdf.font 'Helvetica', style: (is_hi || ci == 0 ? :bold : :normal)
        end

        @pdf.text_box cell,
          at: [cx + 5, row_y - (ri == 0 ? 6 : 4)],
          width: col_w_table - 10

        # Cell border
        @pdf.stroke_color BORDER
        @pdf.line_width 0.3
        @pdf.stroke_rectangle [cx, row_y], col_w_table, (ri == 0 ? 22 : 20)
      end
    end

    # Hosting tier card (for sh / on_premise)
    if @proposal.hosting_tier_info
      tier = @proposal.hosting_tier_info
      hy   = y - rows.size * 20 - 28
      section_title 'Selected Hosting Tier', y: hy
      hy -= 18

      fill_rect MARGIN, hy, PAGE_W - MARGIN * 2, 56, LIGHT_GRAY
      fill_rect MARGIN, hy, 5, 56, RED

      @pdf.fill_color CHARCOAL
      @pdf.font_size 14
      @pdf.font 'Helvetica', style: :bold
      @pdf.text_box tier[:label],
        at: [MARGIN + 18, hy - 12],
        width: 160

      @pdf.fill_color GRAY
      @pdf.font_size 10
      @pdf.font 'Helvetica', style: :normal
      @pdf.text_box tier[:specs],
        at: [MARGIN + 18, hy - 30],
        width: 240

      @pdf.font_size 9
      @pdf.text_box tier[:users],
        at: [MARGIN + 18, hy - 46],
        width: 240

      @pdf.fill_color RED_DARK
      @pdf.font_size 14
      @pdf.font 'Helvetica', style: :bold
      @pdf.text_box "PKR #{number(tier[:annual_pkr])}/yr",
        at: [PAGE_W - MARGIN - 180, hy - 22],
        width: 175,
        align: :right
    end

    page_footer
  end

  # ─── INVESTMENT SUMMARY ────────────────────────────────────────────────────
  def investment_summary
    page_header 'Investment Summary'

    body_text "Transparent breakdown of all costs associated with the proposed " \
              "Odoo ERP implementation for #{@client}.",
              y: PAGE_H - 140

    # Table header
    col_widths = [
      (PAGE_W - MARGIN * 2) * 0.35,
      (PAGE_W - MARGIN * 2) * 0.40,
      (PAGE_W - MARGIN * 2) * 0.25
    ]
    headers = ['Module / Service', 'Description', 'Investment (PKR)']
    y = PAGE_H - 180

    # Header row
    fill_rect MARGIN, y, PAGE_W - MARGIN * 2, 22, RED_DARK

    x_offset = MARGIN
    headers.each_with_index do |h, ci|
      @pdf.fill_color WHITE
      @pdf.font_size 9
      @pdf.font 'Helvetica', style: :bold
      @pdf.text_box h,
        at: [x_offset + 6, y - 5],
        width: col_widths[ci] - 10,
        align: (ci == 2 ? :right : :left)
      x_offset += col_widths[ci]
    end

    # Data rows
    items = @proposal.selected_module_details.map do |mod|
      [clean(mod[:label]), 'Module Configuration & Setup', number(mod[:impl_cost])]
    end

    items.each_with_index do |row, ri|
      row_y = y - 22 - ri * 20
      fill_rect MARGIN, row_y, PAGE_W - MARGIN * 2, 20, ri.even? ? WHITE : LIGHT_GRAY

      x_offset = MARGIN
      row.each_with_index do |cell, ci|
        @pdf.fill_color ci == 2 ? RED_DARK : DARK_GRAY
        @pdf.font_size 9
        @pdf.font 'Helvetica', style: (ci == 0 ? :bold : :normal)
        @pdf.text_box cell,
          at: [x_offset + 6, row_y - 4],
          width: col_widths[ci] - 10,
          align: (ci == 2 ? :right : :left)
        x_offset += col_widths[ci]
      end

      @pdf.stroke_color BORDER
      @pdf.line_width 0.3
      @pdf.stroke_line [MARGIN, row_y], [PAGE_W - MARGIN, row_y]
    end

    # Subtotals
    sub_y = y - 22 - items.size * 20

    draw_total_row 'Implementation Fee (one-time)', @proposal.implementation_fee.to_i, sub_y, LIGHT_GRAY

    if @proposal.annual_hosting_cost > 0
      tier_label = @proposal.hosting_tier_info&.dig(:label).to_s
      draw_total_row "Annual Hosting — #{tier_label}", @proposal.annual_hosting_cost.to_i, sub_y - 22, WHITE
      sub_y -= 22
    end

    # Note box
    note_y = sub_y - 28
    fill_rect MARGIN, note_y, PAGE_W - MARGIN * 2, 22, RED_LIGHT
    fill_rect MARGIN, note_y, 4, 22, RED

    @pdf.fill_color RED_DARK
    @pdf.font_size 9
    @pdf.font 'Helvetica', style: :normal
    @pdf.text_box 'Note: Odoo subscription fees are billed directly by Odoo and are not included in this proposal. ' \
                  'Contact us for current per-user pricing.',
      at: [MARGIN + 12, note_y - 5],
      width: PAGE_W - MARGIN * 2 - 20

    # Grand total bar
    total_y = note_y - 46
    fill_rect MARGIN, total_y, PAGE_W - MARGIN * 2, 40, RED_DARK

    @pdf.fill_color WHITE
    @pdf.font_size 12
    @pdf.font 'Helvetica', style: :bold
    @pdf.text_box 'TOTAL INVESTMENT',
      at: [MARGIN + 16, total_y - 10],
      width: PAGE_W / 2

    @pdf.font_size 18
    @pdf.text_box "PKR #{number(@proposal.total_cost.to_i)}",
      at: [PAGE_W / 2, total_y - 8],
      width: PAGE_W / 2 - MARGIN - 10,
      align: :right

    @pdf.fill_color "FFCDD2"
    @pdf.font_size 9
    @pdf.font 'Helvetica', style: :normal
    @pdf.text_box 'Implementation fee + first year hosting',
      at: [MARGIN + 16, total_y - 28],
      width: PAGE_W / 2

    page_footer
  end

  # ─── NEXT STEPS ────────────────────────────────────────────────────────────
  def next_steps_page
    page_header 'Next Steps'

    body_text "We are excited to partner with #{@client} on this Odoo ERP journey. " \
              "Here is how we recommend moving forward:",
              y: PAGE_H - 140

    steps = [
      { num: '01', title: 'Proposal Review',      time: 'This week',   desc: 'Share this proposal with your team. We are available to present in person or virtually.' },
      { num: '02', title: 'Discovery Workshop',   time: 'Week 1-2',    desc: 'A structured session to finalise requirements, map current workflows and agree on scope.' },
      { num: '03', title: 'Agreement & Kickoff',  time: 'Week 2-3',    desc: 'Sign the service agreement and kick off the implementation with a dedicated project manager.' },
      { num: '04', title: 'Implementation',        time: 'Weeks 4-10',  desc: 'Configuration, customisation, data migration and integrations with weekly progress updates.' },
      { num: '05', title: 'Training & Go-Live',   time: 'Week 10-11',  desc: 'Hands-on team training, UAT sign-off and live deployment on the agreed go-live date.' },
      { num: '06', title: 'Post-Go-Live Support', time: '2 Weeks',     desc: 'Dedicated hypercare period ensuring smooth adoption and rapid resolution of any issues.' }
    ]

    y = PAGE_H - 198
    steps.each do |step|
      # Row background
      fill_rect MARGIN, y, PAGE_W - MARGIN * 2, 50, LIGHT_GRAY

      # Red number circle area
      fill_rect MARGIN, y, 42, 50, RED

      # Step number
      @pdf.fill_color WHITE
      @pdf.font_size 14
      @pdf.font 'Helvetica', style: :bold
      @pdf.text_box step[:num],
        at: [MARGIN + 4, y - 14],
        width: 34,
        align: :center

      # Title
      @pdf.fill_color CHARCOAL
      @pdf.font_size 11
      @pdf.font 'Helvetica', style: :bold
      @pdf.text_box step[:title],
        at: [MARGIN + 56, y - 10],
        width: PAGE_W - MARGIN * 2 - 170

      # Time label (right aligned)
      @pdf.fill_color RED
      @pdf.font_size 9
      @pdf.font 'Helvetica', style: :bold
      @pdf.text_box step[:time],
        at: [PAGE_W - MARGIN - 90, y - 10],
        width: 85,
        align: :right

      # Description
      @pdf.fill_color GRAY
      @pdf.font_size 9
      @pdf.font 'Helvetica', style: :normal
      @pdf.text_box step[:desc],
        at: [MARGIN + 56, y - 28],
        width: PAGE_W - MARGIN * 2 - 110,
        height: 28,
        leading: 3

      # Row border
      @pdf.stroke_color BORDER
      @pdf.line_width 0.3
      @pdf.stroke_line [MARGIN, y - 50], [PAGE_W - MARGIN, y - 50]

      y -= 54
    end

    # Contact CTA block
    y -= 10
    fill_rect MARGIN, y, PAGE_W - MARGIN * 2, 56, CHARCOAL
    fill_rect MARGIN, y, 5, 56, RED

    @pdf.fill_color WHITE
    @pdf.font_size 14
    @pdf.font 'Helvetica', style: :bold
    @pdf.text_box 'Ready to get started?',
      at: [MARGIN + 20, y - 12],
      width: PAGE_W - MARGIN * 2 - 40

    @pdf.fill_color "D1D5DB"
    @pdf.font_size 10
    @pdf.font 'Helvetica', style: :normal
    @pdf.text_box 'info@tecaudex.pk   |   www.tecaudex.pk   |   Tecaudex, Pakistan',
      at: [MARGIN + 20, y - 32],
      width: PAGE_W - MARGIN * 2 - 40

    page_footer
  end

  # ─── SHARED HELPERS ────────────────────────────────────────────────────────

  def page_header(title)
    # Black header bar
    fill_rect 0, PAGE_H, PAGE_W, 80, CHARCOAL

    # Red left accent
    fill_rect 0, PAGE_H, 5, 80, RED

    # Page title
    @pdf.fill_color WHITE
    @pdf.font_size 20
    @pdf.font 'Helvetica', style: :bold
    @pdf.text_box title,
      at: [22, PAGE_H - 22],
      width: PAGE_W - 240

    # Client name (top right)
    @pdf.fill_color "9CA3AF"
    @pdf.font_size 8
    @pdf.font 'Helvetica', style: :normal
    @pdf.text_box "Prepared for #{@client}",
      at: [PAGE_W - 220, PAGE_H - 26],
      width: 210,
      align: :right

    # Date
    @pdf.fill_color "6B7280"
    @pdf.font_size 8
    @pdf.text_box @date,
      at: [PAGE_W - 220, PAGE_H - 42],
      width: 210,
      align: :right

    # Thin red underline
    @pdf.stroke_color RED
    @pdf.line_width 1
    @pdf.stroke_line [0, PAGE_H - 80], [PAGE_W, PAGE_H - 80]
  end

  def page_footer
    fill_rect 0, 28, PAGE_W, 28, LIGHT_GRAY
    fill_rect 0, 28, 4, 28, RED

    @pdf.fill_color GRAY
    @pdf.font_size 8
    @pdf.font 'Helvetica', style: :normal
    @pdf.text_box "Tecaudex  |  Official Odoo Partner  |  www.tecaudex.pk",
      at: [14, 20], width: PAGE_W / 2

    @pdf.text_box "Odoo ERP Proposal  |  #{@client}",
      at: [PAGE_W / 2, 20], width: PAGE_W / 2 - 14, align: :right
  end

  def section_title(title, y:)
    @pdf.fill_color RED
    @pdf.line_width 2
    @pdf.stroke_line [MARGIN, y - 2], [MARGIN + 26, y - 2]

    @pdf.fill_color CHARCOAL
    @pdf.font_size 12
    @pdf.font 'Helvetica', style: :bold
    @pdf.text_box title,
      at: [MARGIN + 32, y + 2],
      width: PAGE_W - MARGIN * 2 - 34
  end

  # Returns new y after drawing text (approximate — 14pt per line)
  def body_text(text, y:)
    @pdf.fill_color DARK_GRAY
    @pdf.font_size 10
    @pdf.font 'Helvetica', style: :normal
    box = @pdf.text_box text,
      at: [MARGIN, y],
      width: PAGE_W - MARGIN * 2,
      leading: 4
    y - 40
  end

  def draw_total_row(label, amount, y, bg)
    fill_rect MARGIN, y, PAGE_W - MARGIN * 2, 22, bg

    @pdf.fill_color DARK_GRAY
    @pdf.font_size 10
    @pdf.font 'Helvetica', style: :bold
    @pdf.text_box label,
      at: [MARGIN + 10, y - 5],
      width: PAGE_W - MARGIN * 2 - 170

    @pdf.fill_color RED_DARK
    @pdf.font_size 10
    @pdf.text_box "PKR #{number(amount)}",
      at: [PAGE_W - MARGIN - 160, y - 5],
      width: 155,
      align: :right

    @pdf.stroke_color BORDER
    @pdf.line_width 0.4
    @pdf.stroke_line [MARGIN, y], [PAGE_W - MARGIN, y]
  end

  # fill_rect draws a solid rectangle. In Prawn coords, y is the TOP edge.
  def fill_rect(x, top_y, width, height, hex_color)
    @pdf.fill_color hex_color
    @pdf.fill_rectangle [x, top_y], width, height
  end

  def number(n)
    n.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  end

  def clean(text)
    text.to_s
        .gsub(/["""]/, '"')
        .gsub(/[''']/, "'")
        .gsub(/[–—]/, '-')
        .gsub(/…/, '...')
        .gsub(/[^\x00-\x7F]/, '')
        .strip
  end
end
