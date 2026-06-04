require "prawn"
require "prawn/table"

# Suppress Prawn font warning
Prawn::Fonts::AFM.hide_m17n_warning = true

class ProposalGenerationService
  def initialize(cost_estimate)
    @cost_estimate = cost_estimate
    @user = @cost_estimate.user
  end

  def generate_pdf
    Prawn::Document.new(page_size: "A4", margin: [ 0, 0, 0, 0 ]) do |pdf|
      # Set up fonts
      setup_document_style(pdf)

      # Cover page
      add_cover_page(pdf)

      # Table of contents
      pdf.start_new_page
      add_table_of_contents(pdf)

      # Executive Summary (if available)
      if @cost_estimate.executive_summary.present?
        pdf.start_new_page
        add_executive_summary(pdf)
      end

      # Similar Apps section (if available)
      if @cost_estimate.similar_apps.present?
        pdf.start_new_page
        add_similar_apps(pdf)
      end

      # Feature Prioritization (if available)
      if @cost_estimate.feature_prioritization.present? && @cost_estimate.features.any?
        pdf.start_new_page
        add_feature_prioritization(pdf)
      end

      # Hours breakdown (if we have features) - compact hierarchical view only
      if @cost_estimate.features.any?
        pdf.start_new_page
        add_hours_breakdown(pdf)
      end

      # Cost estimates
      pdf.start_new_page
      add_cost_estimates(pdf)
    end
  end

  private

  # Color scheme matching Node.js version
  RED_COLOR = "F44336"     # #F44336
  BLACK_COLOR = "000000"   # #000000
  WHITE_COLOR = "FFFFFF"   # #FFFFFF
  GRAY_COLOR = "666666"    # #666666
  LIGHT_GRAY = "808080"    # #808080

  def setup_document_style(pdf)
    pdf.font "Helvetica"
  end

  def sanitize_text(text)
    # Replace problematic UTF-8 characters with Windows-1252 compatible ones
    cleaned_text = text.to_s
        .gsub(/["""]/, '"')      # Replace smart quotes
        .gsub(/[''']/, "'")      # Replace smart apostrophes
        .gsub(/–|—/, "-")        # Replace em/en dashes
        .gsub(/…/, "...")        # Replace ellipsis
        .gsub(/✓/, "v")          # Replace checkmarks
        .gsub(/•/, "-")          # Replace bullet points
        .gsub(/[^\x00-\x7F£€]/, "")   # Remove non-ASCII characters (preserve currency symbols supported by WinAnsi)

    # Try encoding conversion, but fallback to original if it fails
    begin
      cleaned_text.encode("Windows-1252", "UTF-8", invalid: :replace, undef: :replace, replace: "")
    rescue Encoding::UndefinedConversionError
      cleaned_text.gsub(/[^\x20-\x7E£€]/, "") # Keep only printable ASCII + currency symbols if encoding fails
    end
  end

  def add_cover_page(pdf)
    page_width = pdf.bounds.width
    page_height = pdf.bounds.height

    # Black background
    pdf.fill_color BLACK_COLOR
    pdf.fill_rectangle [ 0, page_height ], page_width, page_height

    mx = page_width * 0.08

    # Main title
    pdf.fill_color WHITE_COLOR
    pdf.font_size(page_width * 0.08)
    pdf.text_box sanitize_text("Project Proposal"),
      at: [ mx, page_height * 0.85 ],
      width: page_width - mx * 1.8,
      style: :bold,
      color: WHITE_COLOR

    # Red ellipses
    circle_y = page_height * 0.6
    circle_radius = page_width * 0.08
    circle_spacing = circle_radius * 1.8
    height_scales = [ 0.7, 0.8, 0.9, 1.0 ]

    4.times do |i|
      pdf.fill_color RED_COLOR
      pdf.fill_ellipse [ mx + i * circle_spacing, circle_y ], circle_radius, circle_radius * 1.7 * height_scales[i]
    end

    # Project name - use AI-generated app_name or fallback to project_name or app type
    my = page_height * 0.4 - page_height * 0.1
    pdf.fill_color WHITE_COLOR
    pdf.font_size(page_width * 0.044)
    project_name = @cost_estimate.app_name.present? ?
                   @cost_estimate.app_name :
                   (@cost_estimate.project_name.present? ?
                    @cost_estimate.project_name :
                    (@cost_estimate.app_type_display || "Untitled Project"))
    pdf.text_box sanitize_text(project_name),
      at: [ mx, my ],
      width: page_width - mx * 1.5,
      style: :bold,
      color: WHITE_COLOR

    pdf.font_size 12
    pdf.fill_color GRAY_COLOR
    pdf.text_box sanitize_text("Proposed App Name"),
      at: [ mx, my + 30 ],
      width: page_width - mx * 1.5,
      color: GRAY_COLOR

    # Scale info
    scale_text = @cost_estimate.scale_display.gsub("-", " ").split.map(&:capitalize).join(" ")
    pdf.font_size 13
    pdf.fill_color WHITE_COLOR
    pdf.text_box sanitize_text(scale_text),
      at: [ mx, my - 50 ],
      width: page_width - mx * 1.5,
      style: :bold,
      color: WHITE_COLOR

    # Powered by Tecaudex
    pdf.font_size 12
    pdf.fill_color GRAY_COLOR
    pdf.text_box sanitize_text("Powered by"),
      at: [ mx, page_height * 0.08 ],
      width: page_width - mx * 1.5,
      color: GRAY_COLOR

    pdf.font_size 13
    pdf.fill_color WHITE_COLOR
    pdf.text_box sanitize_text("Tecaudex"),
      at: [ mx, page_height * 0.06 ],
      width: page_width - mx * 1.5,
      style: :bold,
      color: WHITE_COLOR

    # Arrow in bottom right
    arrow_x = page_width * 0.85
    arrow_y = page_height * 0.06
    arrow_length = page_width * 0.08

    pdf.stroke_color RED_COLOR
    pdf.line_width 3
    pdf.stroke_line [ arrow_x, arrow_y ], [ arrow_x + arrow_length, arrow_y ]
    pdf.stroke_line [ arrow_x + arrow_length - 10, arrow_y + 10 ], [ arrow_x + arrow_length, arrow_y ]
    pdf.stroke_line [ arrow_x + arrow_length - 10, arrow_y - 10 ], [ arrow_x + arrow_length, arrow_y ]
  end

  def add_table_of_contents(pdf)
    page_width = pdf.bounds.width
    page_height = pdf.bounds.height

    # Red header section
    pdf.fill_color RED_COLOR
    pdf.fill_rectangle [ 0, page_height ], page_width, page_height * 0.35

    # HTML-style brackets - centered in red section
    bracket_size = page_width * 0.25
    bracket_y = page_height - page_height * 0.18  # Centered vertically in red section
    bracket_spacing = bracket_size * 0.55

    pdf.fill_color WHITE_COLOR
    pdf.font_size bracket_size
    pdf.text_box sanitize_text("<"),
      at: [ 40, bracket_y ],
      style: :bold,
      color: WHITE_COLOR

    pdf.text_box sanitize_text("/"),
      at: [ 40 + bracket_spacing, bracket_y ],
      style: :bold,
      color: WHITE_COLOR

    pdf.text_box sanitize_text(">"),
      at: [ 40 + 1.8 * bracket_spacing, bracket_y ],
      style: :bold,
      color: WHITE_COLOR

    # Title
    pdf.font_size(page_width * 0.051)
    pdf.fill_color RED_COLOR
    pdf.text_box sanitize_text("Table of Contents"),
      at: [ 30, page_height - page_height * 0.48 ],
      style: :bold,
      color: RED_COLOR

    # Contents items
    items = []

    # Add Executive Summary if available
    if @cost_estimate.executive_summary.present?
      items << "Executive Summary"
    end

    # Add Market Research if we have similar apps
    if @cost_estimate.similar_apps.present?
      items << "Market Research"
    end

    # Add Feature Analysis if we have features
    if @cost_estimate.features.any?
      # Add Feature Prioritization if available
      if @cost_estimate.feature_prioritization.present?
        items << "Strategic Roadmap"
      end
      items << "Feature Analysis"
      items << "Hours Breakdown"
    end

    items << "Project Cost & Estimation"

    y_position = page_height - page_height * 0.55
    items.each_with_index do |item, index|
      number = (index + 1).to_s.rjust(2, "0")

      pdf.font_size 19
      pdf.fill_color BLACK_COLOR
      pdf.text_box sanitize_text(number),
        at: [ 33, y_position ],
        style: :bold,
        color: BLACK_COLOR

      pdf.font_size 20
      pdf.text_box sanitize_text(item),
        at: [ 75, y_position ],
        color: BLACK_COLOR

      y_position -= 45
    end
  end

  def add_hours_breakdown(pdf)
    page_height = pdf.bounds.height
    margin_top = page_height * 0.09
    page_width = pdf.bounds.width

    # Page title
    add_page_title(pdf, "Development Timeline", margin_top)

    # Setup table parameters with better spacing
    margin_top_overview = page_height * 0.15
    horizontal_margin = 40
    table_width = page_width - 2 * horizontal_margin
    features_col_width = table_width * 0.75  # 75% for Features
    hours_col_width = table_width * 0.25     # 25% for Hours
    row_height = 35  # Increased for better readability
    font_size = 11
    y_position = page_height - margin_top_overview

    # Table header
    table_data = [ { label: "Features", value: "Hours", is_header: true } ]

    # Add feature data to table (simple like TypeScript)
    grouped_features = @cost_estimate.features.group_by { |f| f["category"] || "General" }
    total_hours = 0

    grouped_features.each do |category, features|
      category_hours = features.sum { |f| f["hours"].to_i }
      total_hours += category_hours

      # Add category as a main row
      table_data << {
        label: category,
        value: "#{category_hours}h",
        is_header: false,
        is_category: true
      }

      # Add each feature under the category
      features.each do |feature|
        feature_name = feature["name"] || "Unnamed Feature"
        feature_hours = feature["hours"].to_i

        table_data << {
          label: "  → #{feature_name}",  # Indent with arrow
          value: "#{feature_hours}h",
          is_header: false,
          is_category: false
        }
      end
    end

    # Add total hours row
    table_data << {
      label: "Total Hours",
      value: "#{total_hours}h",
      is_header: false,
      is_total: true
    }

    # Track table start position for borders
    table_start_y = page_height - margin_top_overview
    is_first_page = true

    # Draw table (exactly like TypeScript implementation)
    table_data.each_with_index do |row, index|
      # Check if we need a new page
      if y_position - row_height < 100
        # No borders - just start new page
        pdf.start_new_page
        add_page_title(pdf, "Hours Breakdown (Continued)", margin_top)
        y_position = page_height - margin_top_overview
        table_start_y = y_position
        is_first_page = false  # Mark that we're no longer on first page
      end

      # Premium row backgrounds with subtle gradients
      if row[:is_header]
        # Header with dark background
        pdf.fill_color "1F2937"
        pdf.fill_rounded_rectangle [ horizontal_margin, y_position ], table_width, row_height, 6
      elsif row[:is_total]
        # Total row - highlighted with dark background
        pdf.fill_color "1F2937"
        pdf.fill_rectangle [ horizontal_margin, y_position ], table_width, row_height
      else
        # Alternate row colors for better readability
        if index.even?
          pdf.fill_color "FAFAFA"
          pdf.fill_rectangle [ horizontal_margin, y_position - row_height ], table_width, row_height
        end
      end

      # Text color based on row type
      text_color = if row[:is_header]
                     WHITE_COLOR
      elsif row[:is_category]
                     BLACK_COLOR
      elsif row[:is_total]
                     WHITE_COLOR
      else
                     "374151"  # Dark gray
      end

      # Font style
      font_style = if row[:is_header] || row[:is_total] || row[:is_category]
                     :bold
      else
                     :normal
      end

      # Clean the text to remove any "?" characters that might appear from encoding issues
      clean_label = sanitize_text(row[:label]).gsub("?", "")
      clean_value = sanitize_text(row[:value]).gsub("?", "")

      # Draw left column text (Features)
      pdf.fill_color text_color
      pdf.font_size font_size
      pdf.text_box clean_label,
        at: [ horizontal_margin + 5, y_position - row_height/2 + font_size/2 ],
        width: features_col_width - 10,
        style: font_style,
        color: text_color

      # Draw right column text (Hours)
      pdf.text_box clean_value,
        at: [ horizontal_margin + features_col_width + 5, y_position - row_height/2 + font_size/2 ],
        width: hours_col_width - 10,
        style: font_style,
        color: text_color

      y_position -= row_height
    end

    # No borders drawn - keeping clean design

    add_page_footer(pdf)
  end

  # Helper method to draw table borders
  def draw_table_borders(pdf, horizontal_margin, table_width, col_divider_position, table_top, table_bottom)
    pdf.stroke_color BLACK_COLOR
    pdf.line_width 1

    # Top border
    pdf.stroke_line [ horizontal_margin, table_top ], [ horizontal_margin + table_width, table_top ]
    # Bottom border
    pdf.stroke_line [ horizontal_margin, table_bottom ], [ horizontal_margin + table_width, table_bottom ]
    # Left border
    pdf.stroke_line [ horizontal_margin, table_top ], [ horizontal_margin, table_bottom ]
    # Right border
    pdf.stroke_line [ horizontal_margin + table_width, table_top ], [ horizontal_margin + table_width, table_bottom ]
    # Column divider
    pdf.stroke_line [ horizontal_margin + col_divider_position, table_top ], [ horizontal_margin + col_divider_position, table_bottom ]
  end

  # Extract sub-features from description text
  def extract_sub_features(description)
    sub_features = []

    # Common patterns for sub-features
    patterns = [
      /([^,]+registration[^,]*)/i,
      /([^,]+verification[^,]*)/i,
      /([^,]+profile[^,]*)/i,
      /([^,]+login[^,]*)/i,
      /([^,]+authentication[^,]*)/i,
      /([^,]+messaging[^,]*)/i,
      /([^,]+notification[^,]*)/i,
      /([^,]+payment[^,]*)/i,
      /([^,]+analytics[^,]*)/i,
      /([^,]+admin[^,]*)/i
    ]

    patterns.each do |pattern|
      matches = description.scan(pattern)
      matches.each do |match|
        clean_match = match.first.to_s.strip.gsub(/^(and|with|or)\s+/i, "")
        sub_features << clean_match if clean_match.length > 5 && clean_match.length < 40
      end
    end

    # If no pattern matches, split by common delimiters
    if sub_features.empty?
      potential_features = description.split(/[,;]/).map(&:strip)
      potential_features.each do |feature|
        if feature.length > 8 && feature.length < 50
          sub_features << feature
        end
      end
    end

    # Return max 3 sub-features
    sub_features.uniq.first(3)
  end

  def add_feature_details(pdf)
    page_height = pdf.bounds.height
    margin_top = page_height * 0.09

    # Page title
    add_page_title(pdf, "Feature Specifications", margin_top)

    current_y = page_height * 0.2
    page_width = pdf.bounds.width
    horizontal_margin = 30

    grouped_features = @cost_estimate.features.group_by { |f| f["category"] || "General" }

    grouped_features.each do |category, features|
      # Check if we need a new page
      space_needed = 60 + (features.count * 80) # Rough estimate
      if current_y - space_needed < 100
        pdf.start_new_page
        add_page_title(pdf, "Feature Specifications (Continued)", margin_top)
        current_y = page_height * 0.2
      end

      # Category header
      pdf.font_size 16
      pdf.fill_color BLACK_COLOR
      pdf.text_box sanitize_text(category.upcase),
        at: [ horizontal_margin, current_y ],
        style: :bold,
        color: BLACK_COLOR

      current_y -= 25

      # Features in this category
      features.each do |feature|
        feature_name = feature["name"] || "Unnamed Feature"
        feature_description = feature["description"] || "No description available"
        feature_hours = feature["hours"].to_i
        feature_complexity = feature["complexity"] || "Medium"

        # Feature name and hours
        pdf.font_size 12
        pdf.fill_color BLACK_COLOR
        pdf.text_box sanitize_text("#{feature_name} (#{feature_hours}h)"),
          at: [ horizontal_margin + 10, current_y ],
          width: page_width - horizontal_margin - 150,
          style: :bold,
          color: BLACK_COLOR

        # Complexity badge
        complexity_color = case feature_complexity.downcase
        when "low" then "22C55E"    # Green
        when "medium" then "F59E0B" # Amber
        when "high" then "EF4444"  # Red
        else "F59E0B"              # Default amber
        end

        pdf.font_size 10
        pdf.fill_color complexity_color
        pdf.text_box sanitize_text(feature_complexity.upcase),
          at: [ page_width - 120, current_y ],
          width: 80,
          style: :bold,
          color: complexity_color

        current_y -= 18

        # Feature description
        pdf.font_size 11
        pdf.fill_color BLACK_COLOR

        # Calculate description height
        description_lines = feature_description.length / 80 + 1
        description_height = [ description_lines * 14, 60 ].min # Max 60px height

        pdf.text_box sanitize_text(feature_description),
          at: [ horizontal_margin + 20, current_y ],
          width: page_width - horizontal_margin - 60,
          height: description_height,
          color: BLACK_COLOR

        current_y -= (description_height + 15)

        # Separator line
        pdf.stroke_color LIGHT_GRAY
        pdf.line_width 1
        pdf.stroke_line [ horizontal_margin + 10, current_y ], [ page_width - horizontal_margin, current_y ]

        current_y -= 10
      end

      current_y -= 20 # Space between categories
    end

    add_page_footer(pdf)
  end

  def add_cost_estimates(pdf)
    page_height = pdf.bounds.height
    page_width = pdf.bounds.width
    margin_top = page_height * 0.09

    # Page title
    add_page_title(pdf, "Project Cost & Estimation", margin_top)

    # Setup table parameters (matching hours breakdown style)
    margin_top_overview = page_height * 0.15
    horizontal_margin = 30
    table_width = page_width - 2 * horizontal_margin
    features_col_width = table_width * 0.7  # 70% for description
    cost_col_width = table_width * 0.3      # 30% for cost/value
    row_height = 30
    font_size = 12
    y_position = page_height - margin_top_overview

    # Calculate costs with breakdown
    hourly_rate = @cost_estimate.hourly_rate
    total_hours = @cost_estimate.total_hours
    development_cost = total_hours * hourly_rate
    total_cost = development_cost

    # Calculate months (assuming 172 hours per month with 0.8 efficiency factor)
    monthly_hours = 172
    total_months = (total_hours.to_f / monthly_hours * 0.8).ceil

    # Calculate feature breakdown if available
    feature_breakdown = {}
    if @cost_estimate.features.any?
      grouped_features = @cost_estimate.features.group_by { |f| f["category"] || "General" }
      grouped_features.each do |category, features|
        category_hours = features.sum { |f| f["hours"].to_i }
        feature_breakdown[category] = category_hours
      end
    end

    # Simplified table data with only total hours and pricing structure
    table_data = [
      { label: "Cost Breakdown", value: "Value", is_header: true },
      { label: "Total Development Hours", value: "#{total_hours} hours" },
      { label: "Development Rate", value: "£#{hourly_rate}/hour" },
      { label: "Development Cost", value: "£#{number_with_commas(development_cost.to_i)}" },
      { label: "Quality Assurance", value: "Included" },
      { label: "Documentation", value: "Included" },
      { label: "Total Project Investment", value: "£#{number_with_commas(total_cost.to_i)}", is_total: true }
    ]

    # Track table start position for borders
    table_start_y = page_height - margin_top_overview
    is_first_page = true

    # Draw table (matching hours breakdown styling)
    table_data.each_with_index do |row, index|
      # Check if we need space (though cost table should fit on one page)
      if y_position - row_height < 100
        # No borders - just start new page
        pdf.start_new_page
        add_page_title(pdf, "Project Cost & Estimation (Continued)", margin_top)
        y_position = page_height - margin_top_overview
        table_start_y = y_position  # Reset table start for new page
        is_first_page = false  # Mark that we're no longer on first page
      end

      # Draw background for different row types (matching hours breakdown style)
      if row[:is_header]
        # Header with dark background (matching hours breakdown)
        pdf.fill_color "1F2937"
        pdf.fill_rounded_rectangle [ horizontal_margin, y_position ], table_width, row_height, 6
      elsif row[:is_category]
        # Light red background for category headers
        pdf.fill_color "FEF2F2"
        pdf.fill_rectangle [ horizontal_margin, y_position - row_height ], table_width, row_height
        # Add subtle left border accent
        pdf.fill_color RED_COLOR
        pdf.fill_rectangle [ horizontal_margin, y_position - row_height ], 4, row_height
      elsif row[:is_total]
        # Total row - highlighted with dark background (matching hours breakdown)
        pdf.fill_color "1F2937"
        pdf.fill_rectangle [ horizontal_margin, y_position ], table_width, row_height
      else
        # Alternate row colors for better readability (matching hours breakdown)
        if index.even?
          pdf.fill_color "FAFAFA"
          pdf.fill_rectangle [ horizontal_margin, y_position - row_height ], table_width, row_height
        end
      end

      # Text color based on row type (matching hours breakdown)
      text_color = if row[:is_header]
                     WHITE_COLOR
      elsif row[:is_category]
                     RED_COLOR
      elsif row[:is_total]
                     WHITE_COLOR
      else
                     "374151"  # Dark gray
      end

      # Font style
      font_style = if row[:is_header] || row[:is_total] || row[:is_category]
                     :bold
      else
                     :normal
      end

      # Clean the text
      clean_label = sanitize_text(row[:label]).gsub("?", "")
      clean_value = sanitize_text(row[:value]).gsub("?", "")

      # Draw left column text
      pdf.fill_color text_color
      pdf.font_size font_size
      pdf.text_box clean_label,
        at: [ horizontal_margin + 5, y_position - row_height/2 + font_size/2 ],
        width: features_col_width - 10,
        style: font_style,
        color: text_color

      # Draw right column text
      unless row[:value].empty?
        pdf.text_box clean_value,
          at: [ horizontal_margin + features_col_width + 5, y_position - row_height/2 + font_size/2 ],
          width: cost_col_width - 10,
          style: font_style,
          color: text_color
      end

      y_position -= row_height
    end

    # No borders drawn - keeping clean design

    # Add Timeline section from Technical Information
    if @cost_estimate.technical_information_summary.present?
      begin
        tech_info = JSON.parse(@cost_estimate.technical_information_summary)
        if tech_info["estimated_timeline"].present?
          y_position -= 40

          pdf.font_size 14
          pdf.fill_color BLACK_COLOR
          pdf.text_box sanitize_text("Estimated Timeline"),
            at: [ horizontal_margin, y_position ],
            style: :bold,
            color: BLACK_COLOR

          y_position -= 30

          # Timeline display
          pdf.font_size 11
          pdf.fill_color "374151"
          pdf.text_box sanitize_text(tech_info["estimated_timeline"]),
            at: [ horizontal_margin, y_position ],
            width: table_width,
            leading: 4,
            color: "374151"

          timeline_lines = (tech_info["estimated_timeline"].length / 80.0).ceil
          y_position -= (timeline_lines * 16)
        end
      rescue JSON::ParserError
        # Skip timeline if parsing fails
      end
    end

    # Cost analysis section
    y_position -= 40

    pdf.font_size 14
    pdf.fill_color BLACK_COLOR
    pdf.text_box sanitize_text("Value Proposition"),
      at: [ horizontal_margin, y_position ],
      style: :bold,
      color: BLACK_COLOR

    y_position -= 25

    # Cost breakdown insights
    pdf.font_size 11
    cost_insights = [
      "• Industry-competitive hourly rate of £#{hourly_rate}",
      "• Comprehensive development including QA and documentation",
      "• Professional project management included"
    ]

    cost_insights.each do |insight|
      pdf.text_box sanitize_text(insight),
        at: [ horizontal_margin + 10, y_position ],
        width: table_width - 20,
        color: BLACK_COLOR

      y_position -= 15
    end


    add_page_footer(pdf)
  end

  def add_similar_apps(pdf)
    page_height = pdf.bounds.height
    margin_top = page_height * 0.09
    page_width = pdf.bounds.width

    # Page title
    add_page_title(pdf, "Market Research", margin_top)

    # Parse similar apps JSON
    begin
      similar_apps = JSON.parse(@cost_estimate.similar_apps)
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse similar_apps: #{e.message}")
      similar_apps = []
    end

    current_y = page_height - (page_height * 0.15)  # Start from top, leave margin
    horizontal_margin = 40

    # Premium section intro
    pdf.font_size 15
    pdf.fill_color BLACK_COLOR
    pdf.text_box sanitize_text("Competitive Landscape"),
      at: [ horizontal_margin, current_y ],
      style: :bold,
      color: BLACK_COLOR

    current_y -= 30

    pdf.font_size 11
    pdf.fill_color GRAY_COLOR
    pdf.text_box sanitize_text("We've conducted thorough market research and identified these comparable solutions that address similar challenges:"),
      at: [ horizontal_margin, current_y ],
      width: page_width - 2 * horizontal_margin,
      color: GRAY_COLOR,
      leading: 3

    current_y -= 40

    # Display similar apps in compact grid - all on one page
    if similar_apps.any?
      similar_apps.each_with_index do |app, index|
        app_name = app["name"] || "Unknown App"
        app_description = app["description"] || "No description available"

        # Even more compact card design
        card_height = 65
        pdf.fill_color "F9FAFB"
        pdf.fill_rounded_rectangle [ horizontal_margin, current_y ], page_width - 2 * horizontal_margin, card_height, 6

        # Left accent bar
        pdf.fill_color RED_COLOR
        pdf.fill_rectangle [ horizontal_margin, current_y ], 4, card_height

        # Number badge - compact circle
        badge_size = 28
        pdf.fill_color RED_COLOR
        pdf.fill_circle [ horizontal_margin + 25, current_y - card_height/2 ], badge_size/2

        pdf.fill_color WHITE_COLOR
        pdf.font_size 13
        pdf.text_box sanitize_text((index + 1).to_s),
          at: [ horizontal_margin + 25 - badge_size/4, current_y - card_height/2 + 5 ],
          width: badge_size/2,
          align: :center,
          style: :bold,
          color: WHITE_COLOR

        # App name
        pdf.fill_color BLACK_COLOR
        pdf.font_size 13
        pdf.text_box sanitize_text(app_name),
          at: [ horizontal_margin + 55, current_y - 18 ],
          width: page_width - 2 * horizontal_margin - 70,
          style: :bold,
          color: BLACK_COLOR

        # App description - compact
        pdf.font_size 9
        pdf.fill_color "6B7280"
        pdf.text_box sanitize_text(app_description),
          at: [ horizontal_margin + 55, current_y - 36 ],
          width: page_width - 2 * horizontal_margin - 70,
          height: 30,
          color: "6B7280",
          leading: 2,
          overflow: :shrink_to_fit

        current_y -= (card_height + 10)  # Tighter spacing
      end
    else
      # No similar apps message
      pdf.font_size 11
      pdf.fill_color GRAY_COLOR
      pdf.text_box sanitize_text("No comparable applications identified at this time."),
        at: [ horizontal_margin, current_y ],
        width: page_width - 2 * horizontal_margin,
        color: GRAY_COLOR,
        style: :italic
    end

    add_page_footer(pdf)
  end

  def add_mockups_section(pdf)
    page_height = pdf.bounds.height
    margin_top = page_height * 0.09
    page_width = pdf.bounds.width

    # Page title
    add_page_title(pdf, "Design Concepts", margin_top)

    current_y = page_height * 0.2
    horizontal_margin = 40

    # Section intro
    pdf.font_size 15
    pdf.fill_color BLACK_COLOR
    pdf.text_box sanitize_text("Visual Concept"),
      at: [ horizontal_margin, current_y ],
      style: :bold,
      color: BLACK_COLOR

    current_y -= 28

    pdf.font_size 11
    pdf.fill_color GRAY_COLOR
    pdf.text_box sanitize_text("Below are conceptual mockups demonstrating the user interface design direction for #{@cost_estimate.app_name || 'your application'}:"),
      at: [ horizontal_margin, current_y ],
      width: page_width - 2 * horizontal_margin,
      color: GRAY_COLOR,
      leading: 3

    current_y -= 45

    app_types = @cost_estimate.application_types_array
    features = @cost_estimate.proposed_features_array.presence || @cost_estimate.features

    if app_types.any? { |type| type.downcase.include?("web") }
      # WEB APPLICATION MOCKUP - Premium Design
      pdf.font_size 13
      pdf.fill_color BLACK_COLOR
      pdf.text_box sanitize_text("WEB APPLICATION INTERFACE"),
        at: [ horizontal_margin, current_y ],
        style: :bold,
        color: BLACK_COLOR

      current_y -= 25

      # Modern browser window with shadow effect
      browser_width = page_width - 2 * horizontal_margin
      browser_height = 240

      # Shadow effect
      pdf.fill_color "E5E7EB"
      pdf.fill_rounded_rectangle [ horizontal_margin + 2, current_y - 2 ], browser_width, browser_height, 8

      # Browser chrome - modern gradient effect (simulated with layers)
      pdf.fill_color "F9FAFB"
      pdf.fill_rounded_rectangle [ horizontal_margin, current_y ], browser_width, browser_height, 8

      # Top bar
      pdf.fill_color "FFFFFF"
      pdf.fill_rounded_rectangle [ horizontal_margin, current_y ], browser_width, 35, 8

      # Browser controls
      3.times do |i|
        color = [ "EF4444", "F59E0B", "10B981" ][i]
        pdf.fill_color color
        pdf.fill_circle [ horizontal_margin + 15 + (i * 18), current_y - 17 ], 5
      end

      # URL bar
      pdf.fill_color "F3F4F6"
      pdf.fill_rounded_rectangle [ horizontal_margin + 80, current_y - 26 ], browser_width - 200, 18, 9
      pdf.fill_color "9CA3AF"
      pdf.font_size 8
      pdf.text_box sanitize_text("https://#{(@cost_estimate.app_name || 'app').downcase.gsub(' ', '')}.com"),
        at: [ horizontal_margin + 90, current_y - 14 ],
        color: "9CA3AF"

      # Main content area with gradient header
      content_y = current_y - 35

      # Hero section with gradient (simulated)
      pdf.fill_color "DC2626"
      pdf.fill_rectangle [ horizontal_margin, content_y ], browser_width, 60
      pdf.fill_color "EF4444"
      pdf.fill_rectangle [ horizontal_margin, content_y - 30 ], browser_width, 30

      # Hero text
      pdf.fill_color WHITE_COLOR
      pdf.font_size 14
      pdf.text_box sanitize_text(@cost_estimate.app_name || "Your Application"),
        at: [ horizontal_margin + 20, content_y - 15 ],
        width: browser_width - 40,
        style: :bold,
        color: WHITE_COLOR

      pdf.font_size 9
      pdf.text_box sanitize_text("Transforming your business workflow"),
        at: [ horizontal_margin + 20, content_y - 35 ],
        width: browser_width - 40,
        color: WHITE_COLOR

      # Feature cards section
      card_y = content_y - 70
      pdf.fill_color WHITE_COLOR
      pdf.fill_rectangle [ horizontal_margin, card_y ], browser_width, 135

      # Three feature cards
      card_width = (browser_width - 60) / 3
      feature_names = features.first(3).map { |f| f["name"] || f[:name] }

      3.times do |i|
        card_x = horizontal_margin + 15 + (i * (card_width + 15))

        # Card with subtle shadow
        pdf.fill_color "F9FAFB"
        pdf.fill_rounded_rectangle [ card_x, card_y - 10 ], card_width, 110, 6

        # Red accent top border
        pdf.fill_color RED_COLOR
        pdf.fill_rounded_rectangle [ card_x, card_y - 10 ], card_width, 3, 1

        # Icon placeholder (circle)
        pdf.fill_color "FEE2E2"
        pdf.fill_circle [ card_x + card_width/2, card_y - 35 ], 15
        pdf.fill_color RED_COLOR
        pdf.fill_circle [ card_x + card_width/2, card_y - 35 ], 12

        # Feature name
        pdf.fill_color BLACK_COLOR
        pdf.font_size 9
        feature_text = feature_names[i] || "Feature #{i + 1}"
        pdf.text_box sanitize_text(feature_text),
          at: [ card_x + 5, card_y - 60 ],
          width: card_width - 10,
          height: 40,
          align: :center,
          style: :bold,
          overflow: :shrink_to_fit,
          color: BLACK_COLOR
      end

      current_y -= (browser_height + 30)
    end

    if app_types.any? { |type| type.downcase.include?("mobile") }
      if current_y < 350
        pdf.start_new_page
        add_page_title(pdf, "Design Concepts (Continued)", margin_top)
        current_y = page_height * 0.2
      end

      # MOBILE APPLICATION MOCKUP - Premium Design
      pdf.font_size 13
      pdf.fill_color BLACK_COLOR
      pdf.text_box sanitize_text("MOBILE APPLICATION INTERFACE"),
        at: [ horizontal_margin, current_y ],
        style: :bold,
        color: BLACK_COLOR

      current_y -= 30

      # Two phone mockups side by side
      phone_width = 160
      phone_height = 300
      spacing = 40
      total_width = phone_width * 2 + spacing
      start_x = (page_width - total_width) / 2

      # Left phone - Dashboard view
      phone_x = start_x

      # Phone shadow
      pdf.fill_color "D1D5DB"
      pdf.fill_rounded_rectangle [ phone_x + 3, current_y - 3 ], phone_width, phone_height, 25

      # Phone frame
      pdf.fill_color "1F2937"
      pdf.fill_rounded_rectangle [ phone_x, current_y ], phone_width, phone_height, 25

      # Notch
      pdf.fill_color BLACK_COLOR
      notch_width = 80
      pdf.fill_rounded_rectangle [ phone_x + (phone_width - notch_width)/2, current_y ], notch_width, 18, 9

      # Screen
      pdf.fill_color WHITE_COLOR
      pdf.fill_rounded_rectangle [ phone_x + 10, current_y - 20 ], phone_width - 20, phone_height - 40, 20

      # Status bar
      pdf.fill_color RED_COLOR
      pdf.fill_rectangle [ phone_x + 10, current_y - 20 ], phone_width - 20, 35

      # App name on status bar
      pdf.fill_color WHITE_COLOR
      pdf.font_size 11
      pdf.text_box sanitize_text(@cost_estimate.app_name || "App"),
        at: [ phone_x + 20, current_y - 35 ],
        width: phone_width - 40,
        style: :bold,
        align: :center,
        color: WHITE_COLOR

      # Dashboard content
      screen_y = current_y - 55

      # Stats cards
      2.times do |i|
        card_y = screen_y - (i * 60)
        pdf.fill_color "F9FAFB"
        pdf.fill_rounded_rectangle [ phone_x + 20, card_y ], phone_width - 40, 50, 8

        # Red accent
        pdf.fill_color RED_COLOR
        pdf.fill_rounded_rectangle [ phone_x + 20, card_y ], 3, 50, 1

        # Stat text
        pdf.fill_color BLACK_COLOR
        pdf.font_size 8
        stat_names = features.first(2).map { |f| (f["name"] || f[:name]).to_s.split(" ").first(2).join(" ") }
        pdf.text_box sanitize_text(stat_names[i] || "Feature #{i + 1}"),
          at: [ phone_x + 30, card_y - 12 ],
          width: phone_width - 60,
          color: BLACK_COLOR,
          style: :bold

        pdf.fill_color RED_COLOR
        pdf.font_size 14
        pdf.text_box sanitize_text("#{(i + 1) * 10}+"),
          at: [ phone_x + 30, card_y - 32 ],
          width: phone_width - 60,
          color: RED_COLOR,
          style: :bold
      end

      # Bottom navigation
      nav_y = current_y - phone_height + 50
      pdf.fill_color "F9FAFB"
      pdf.fill_rectangle [ phone_x + 10, nav_y ], phone_width - 20, 35

      4.times do |i|
        icon_x = phone_x + 20 + (i * 30)
        color = i == 0 ? RED_COLOR : "9CA3AF"
        pdf.fill_color color
        pdf.fill_circle [ icon_x, nav_y - 17 ], 6
      end

      # Right phone - Detail view
      phone_x = start_x + phone_width + spacing

      # Phone shadow
      pdf.fill_color "D1D5DB"
      pdf.fill_rounded_rectangle [ phone_x + 3, current_y - 3 ], phone_width, phone_height, 25

      # Phone frame
      pdf.fill_color "1F2937"
      pdf.fill_rounded_rectangle [ phone_x, current_y ], phone_width, phone_height, 25

      # Notch
      pdf.fill_color BLACK_COLOR
      pdf.fill_rounded_rectangle [ phone_x + (phone_width - notch_width)/2, current_y ], notch_width, 18, 9

      # Screen
      pdf.fill_color WHITE_COLOR
      pdf.fill_rounded_rectangle [ phone_x + 10, current_y - 20 ], phone_width - 20, phone_height - 40, 20

      # Header with back button
      pdf.fill_color WHITE_COLOR
      pdf.fill_rectangle [ phone_x + 10, current_y - 20 ], phone_width - 20, 40

      # Back arrow
      pdf.fill_color BLACK_COLOR
      pdf.fill_circle [ phone_x + 25, current_y - 40 ], 8
      pdf.stroke_color WHITE_COLOR
      pdf.line_width 2
      pdf.stroke_line [ phone_x + 28, current_y - 40 ], [ phone_x + 22, current_y - 40 ]

      # Page title
      pdf.fill_color BLACK_COLOR
      pdf.font_size 10
      pdf.text_box sanitize_text("Details"),
        at: [ phone_x + 45, current_y - 36 ],
        width: phone_width - 80,
        style: :bold,
        color: BLACK_COLOR

      # Content area with list items
      list_y = current_y - 70

      3.times do |i|
        item_y = list_y - (i * 55)

        # List item card
        pdf.fill_color "F9FAFB"
        pdf.fill_rounded_rectangle [ phone_x + 20, item_y ], phone_width - 40, 45, 6

        # Image placeholder
        pdf.fill_color "FEE2E2"
        pdf.fill_rounded_rectangle [ phone_x + 28, item_y - 8 ], 30, 30, 4
        pdf.fill_color RED_COLOR
        pdf.fill_circle [ phone_x + 43, item_y - 23 ], 8

        # Text
        pdf.fill_color BLACK_COLOR
        pdf.font_size 8
        feature_text = features[i] ? (features[i]["name"] || features[i][:name]).to_s.split(" ").first(3).join(" ") : "Item #{i + 1}"
        pdf.text_box sanitize_text(feature_text),
          at: [ phone_x + 65, item_y - 12 ],
          width: phone_width - 90,
          color: BLACK_COLOR,
          style: :bold

        pdf.fill_color GRAY_COLOR
        pdf.font_size 7
        pdf.text_box sanitize_text("View details"),
          at: [ phone_x + 65, item_y - 25 ],
          width: phone_width - 90,
          color: GRAY_COLOR
      end

      current_y -= (phone_height + 20)
    end

    # Footer note
    if current_y < 100
      pdf.start_new_page
      current_y = page_height - 100
    end

    pdf.font_size 9
    pdf.fill_color GRAY_COLOR
    pdf.text_box sanitize_text("* These are conceptual mockups. Final designs will be created during the development phase based on your brand guidelines and preferences."),
      at: [ horizontal_margin, current_y - 20 ],
      width: page_width - 2 * horizontal_margin,
      color: GRAY_COLOR,
      style: :italic

    add_page_footer(pdf)
  end

  def add_page_title(pdf, title, margin_top)
    page_height = pdf.bounds.height

    pdf.font_size 24
    pdf.fill_color RED_COLOR
    pdf.text_box sanitize_text(title),
      at: [ 30, page_height - margin_top ],
      style: :bold,
      color: RED_COLOR

    # Underline
    pdf.stroke_color RED_COLOR
    pdf.line_width 6
    pdf.stroke_line [ 30, page_height - margin_top + 30 ], [ 170, page_height - margin_top + 30 ]
  end

  def add_executive_summary(pdf)
    page_height = pdf.bounds.height
    margin_top = page_height * 0.09
    page_width = pdf.bounds.width

    # Page title
    add_page_title(pdf, "Executive Summary", margin_top)

    # Parse executive summary JSON
    begin
      exec_summary = JSON.parse(@cost_estimate.executive_summary)

      margin_top_content = page_height * 0.2
      y_position = page_height - margin_top_content

      # THE OPPORTUNITY section
      pdf.fill_color BLACK_COLOR
      pdf.font_size 16
      pdf.text_box sanitize_text("The Opportunity"),
        at: [ 30, y_position ],
        width: 535,
        style: :bold,
        color: BLACK_COLOR

      y_position -= 30

      pdf.font_size 11
      pdf.fill_color "374151"
      pdf.text_box sanitize_text(exec_summary["problem_statement"]),
        at: [ 30, y_position ],
        width: 535,
        leading: 5,
        color: "374151"

      problem_lines = (exec_summary["problem_statement"].length / 90.0).ceil
      y_position -= (15 + (problem_lines * 16))

      # OUR SOLUTION section
      pdf.fill_color BLACK_COLOR
      pdf.font_size 16
      pdf.text_box sanitize_text("Our Solution"),
        at: [ 30, y_position ],
        width: 535,
        style: :bold,
        color: BLACK_COLOR

      y_position -= 30

      pdf.font_size 11
      pdf.fill_color "374151"
      pdf.text_box sanitize_text(exec_summary["proposed_solution"]),
        at: [ 30, y_position ],
        width: 535,
        leading: 5,
        color: "374151"

      solution_lines = (exec_summary["proposed_solution"].length / 90.0).ceil
      y_position -= (15 + (solution_lines * 16))

      # KEY BENEFITS section
      pdf.fill_color BLACK_COLOR
      pdf.font_size 16
      pdf.text_box sanitize_text("Key Benefits"),
        at: [ 30, y_position ],
        width: 535,
        style: :bold,
        color: BLACK_COLOR

      y_position -= 30

      exec_summary["key_value_propositions"].each_with_index do |vp, index|
        # Red number
        pdf.fill_color RED_COLOR
        pdf.font "Helvetica", style: :bold
        pdf.font_size 11
        pdf.text_box "#{index + 1}.",
          at: [ 35, y_position ],
          width: 15,
          color: RED_COLOR

        # Value proposition text
        pdf.font "Helvetica"
        pdf.font_size 11
        pdf.fill_color "374151"
        pdf.text_box sanitize_text(vp),
          at: [ 55, y_position ],
          width: 510,
          leading: 4,
          color: "374151"

        vp_lines = (vp.length / 87.0).ceil
        y_position -= (vp_lines * 16)
      end

      y_position -= 20

      # INVESTMENT POTENTIAL section
      pdf.fill_color BLACK_COLOR
      pdf.font_size 16
      pdf.text_box sanitize_text("Investment Potential"),
        at: [ 30, y_position ],
        width: 535,
        style: :bold,
        color: BLACK_COLOR

      y_position -= 30

      pdf.font_size 11
      pdf.fill_color "374151"
      pdf.text_box sanitize_text(exec_summary["roi_potential"]),
        at: [ 30, y_position ],
        width: 535,
        leading: 5,
        color: "374151"

    rescue JSON::ParserError => e
      # Fallback if JSON parsing fails
      pdf.font_size 11
      pdf.text_box sanitize_text("Executive summary data unavailable."),
        at: [ 30, page_height - page_height * 0.2 ],
        width: 535,
        color: GRAY_COLOR
    end

    add_page_footer(pdf)
  end

  def add_feature_prioritization(pdf)
    page_height = pdf.bounds.height
    margin_top = page_height * 0.09
    page_width = pdf.bounds.width

    # Page title
    add_page_title(pdf, "Strategic Roadmap", margin_top)

    # Parse feature prioritization JSON
    begin
      prioritization = JSON.parse(@cost_estimate.feature_prioritization)

      margin_top_content = page_height * 0.2
      y_position = page_height - margin_top_content

      # Iterate through the three phases
      phases = [
        { key: "phase_1_mvp", title: "Phase 1: MVP Launch", icon: "🚀" },
        { key: "phase_2_growth", title: "Phase 2: Growth & Engagement", icon: "📈" },
        { key: "phase_3_scale", title: "Phase 3: Scale & Leadership", icon: "🏆" }
      ]

      phases.each_with_index do |phase_info, phase_index|
        phase = prioritization[phase_info[:key]]
        next unless phase

        # Check if we need a new page
        if y_position < 250
          pdf.start_new_page
          add_page_title(pdf, "Strategic Roadmap (Continued)", margin_top)
          y_position = page_height - margin_top_content
        end

        # Phase header with icon
        pdf.fill_color BLACK_COLOR
        pdf.font_size 16
        pdf.text_box sanitize_text("#{phase_info[:icon]} #{phase_info[:title]}"),
          at: [ 30, y_position ],
          width: 535,
          style: :bold,
          color: BLACK_COLOR

        y_position -= 30

        # Description
        pdf.font_size 11
        pdf.fill_color "6B7280"
        pdf.text_box sanitize_text(phase["description"]),
          at: [ 30, y_position ],
          width: 535,
          leading: 4,
          color: "6B7280"

        desc_lines = (phase["description"].length / 90.0).ceil
        y_position -= (10 + (desc_lines * 14))

        # Features list with numbered bullets
        phase["features"].each_with_index do |feature, index|
          # Red number
          pdf.fill_color RED_COLOR
          pdf.font "Helvetica", style: :bold
          pdf.font_size 11
          pdf.text_box "#{index + 1}.",
            at: [ 35, y_position ],
            width: 15,
            color: RED_COLOR

          # Feature text
          pdf.font "Helvetica"
          pdf.font_size 11
          pdf.fill_color BLACK_COLOR
          pdf.text_box sanitize_text(feature),
            at: [ 55, y_position ],
            width: 510,
            color: BLACK_COLOR

          feature_lines = (feature.length / 87.0).ceil
          y_position -= (feature_lines * 16)
        end

        # Add spacing between phases
        y_position -= 20
      end

    rescue JSON::ParserError => e
      # Fallback if JSON parsing fails
      pdf.font_size 11
      pdf.text_box sanitize_text("Feature prioritization data unavailable."),
        at: [ 30, page_height - page_height * 0.2 ],
        width: 535,
        color: GRAY_COLOR
    end

    add_page_footer(pdf)
  end

  def add_page_footer(pdf)
    footer_y = 40
    start_x = 50
    page_width = pdf.bounds.width
    content_width = page_width - (2 * start_x)

    # Subtle separator line
    pdf.stroke_color RED_COLOR
    pdf.line_width 1
    pdf.stroke_line [ start_x, footer_y + 25 ], [ start_x + content_width, footer_y + 25 ]

    # Simple centered footer with just company name
    pdf.font_size 10
    pdf.fill_color GRAY_COLOR
    pdf.text_box sanitize_text("Tecaudex"),
      at: [ start_x, footer_y ],
      width: content_width,
      align: :center,
      style: :bold,
      color: GRAY_COLOR
  end

  def number_with_commas(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
