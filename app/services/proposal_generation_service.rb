require 'prawn'
require 'prawn/table'

# Suppress Prawn font warning
Prawn::Fonts::AFM.hide_m17n_warning = true

class ProposalGenerationService
  def initialize(cost_estimate)
    @cost_estimate = cost_estimate
    @user = @cost_estimate.user
  end

  def generate_pdf
    Prawn::Document.new(page_size: 'A4', margin: [0, 0, 0, 0]) do |pdf|
      # Set up fonts
      setup_document_style(pdf)
      
      # Cover page
      add_cover_page(pdf)
      
      # Table of contents
      pdf.start_new_page
      add_table_of_contents(pdf)
      
      # Project overview/crux
      pdf.start_new_page
      add_project_overview(pdf)
      
      # Hours breakdown (if we have features)
      if @cost_estimate.features.any?
        pdf.start_new_page
        add_hours_breakdown(pdf)
        
        # Feature details page (if we have complex features with descriptions)
        complex_features = @cost_estimate.features.select { |f| f['description'].present? && f['description'].length > 20 }
        if complex_features.count > 3
          pdf.start_new_page
          add_feature_details(pdf)
        end
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
    text.to_s
        .gsub(/["""]/, '"')      # Replace smart quotes
        .gsub(/[''']/, "'")      # Replace smart apostrophes
        .gsub(/–|—/, '-')        # Replace em/en dashes
        .gsub(/…/, '...')        # Replace ellipsis
        .gsub(/✓/, 'v')          # Replace checkmarks
        .gsub(/•/, '-')          # Replace bullet points
        .gsub(/[^\u0000-\u00FF]/, '?') # Replace any remaining non-Windows-1252 chars
        .encode('Windows-1252', 'UTF-8', invalid: :replace, undef: :replace)
  rescue Encoding::UndefinedConversionError
    text.to_s.encode('Windows-1252', 'UTF-8', invalid: :replace, undef: :replace, replace: '?')
  end

  def add_cover_page(pdf)
    page_width = pdf.bounds.width
    page_height = pdf.bounds.height
    
    # Black background
    pdf.fill_color BLACK_COLOR
    pdf.fill_rectangle [0, page_height], page_width, page_height
    
    mx = page_width * 0.08

    # Main title
    pdf.fill_color WHITE_COLOR
    pdf.font_size(page_width * 0.08)
    pdf.text_box sanitize_text("Cost Calculator Report!"), 
      at: [mx, page_height * 0.85], 
      width: page_width - mx * 1.8,
      style: :bold,
      color: WHITE_COLOR

    # Red ellipses
    circle_y = page_height * 0.6
    circle_radius = page_width * 0.08
    circle_spacing = circle_radius * 1.8
    height_scales = [0.7, 0.8, 0.9, 1.0]

    4.times do |i|
      pdf.fill_color RED_COLOR
      pdf.fill_ellipse [mx + i * circle_spacing, circle_y], circle_radius, circle_radius * 1.7 * height_scales[i]
    end

    # Project name
    my = page_height * 0.4 - page_height * 0.1
    pdf.fill_color WHITE_COLOR
    pdf.font_size(page_width * 0.044)
    pdf.text_box sanitize_text(@cost_estimate.app_type_display || "Untitled Project"), 
      at: [mx, my], 
      width: page_width - mx * 1.5,
      style: :bold,
      color: WHITE_COLOR

    pdf.font_size 12
    pdf.fill_color GRAY_COLOR
    pdf.text_box sanitize_text("Proposed App Name"), 
      at: [mx, my + 30], 
      width: page_width - mx * 1.5,
      color: GRAY_COLOR

    # Scale info
    scale_text = @cost_estimate.scale_display.gsub('-', ' ').split.map(&:capitalize).join(' ')
    pdf.font_size 13
    pdf.fill_color WHITE_COLOR
    pdf.text_box sanitize_text(scale_text), 
      at: [mx, my - 50], 
      width: page_width - mx * 1.5,
      style: :bold,
      color: WHITE_COLOR

    # Powered by Tecaudex
    pdf.font_size 12
    pdf.fill_color GRAY_COLOR
    pdf.text_box sanitize_text("Powered by"), 
      at: [mx, page_height * 0.08], 
      width: page_width - mx * 1.5,
      color: GRAY_COLOR

    pdf.font_size 13
    pdf.fill_color WHITE_COLOR
    pdf.text_box sanitize_text("Tecaudex"), 
      at: [mx, page_height * 0.06], 
      width: page_width - mx * 1.5,
      style: :bold,
      color: WHITE_COLOR

    # Arrow in bottom right
    arrow_x = page_width * 0.85
    arrow_y = page_height * 0.06
    arrow_length = page_width * 0.08

    pdf.stroke_color RED_COLOR
    pdf.line_width 3
    pdf.stroke_line [arrow_x, arrow_y], [arrow_x + arrow_length, arrow_y]
    pdf.stroke_line [arrow_x + arrow_length - 10, arrow_y + 10], [arrow_x + arrow_length, arrow_y]
    pdf.stroke_line [arrow_x + arrow_length - 10, arrow_y - 10], [arrow_x + arrow_length, arrow_y]
  end

  def add_table_of_contents(pdf)
    page_width = pdf.bounds.width
    page_height = pdf.bounds.height

    # Red header section
    pdf.fill_color RED_COLOR
    pdf.fill_rectangle [0, page_height], page_width, page_height * 0.4

    # HTML-style brackets
    bracket_size = page_width * 0.3
    bracket_y = page_height - page_height * 0.3
    bracket_spacing = bracket_size * 0.6

    pdf.fill_color WHITE_COLOR
    pdf.font_size bracket_size
    pdf.text_box sanitize_text("<"), 
      at: [30, bracket_y], 
      style: :bold,
      color: WHITE_COLOR

    pdf.text_box sanitize_text("/"), 
      at: [30 + bracket_spacing, bracket_y], 
      style: :bold,
      color: WHITE_COLOR

    pdf.text_box sanitize_text(">"), 
      at: [30 + 1.8 * bracket_spacing, bracket_y], 
      style: :bold,
      color: WHITE_COLOR

    # Title
    pdf.font_size(page_width * 0.051)
    pdf.fill_color RED_COLOR
    pdf.text_box sanitize_text("Table of Contents"), 
      at: [30, page_height - page_height * 0.48], 
      style: :bold,
      color: RED_COLOR

    # Contents items
    items = [
      "Project Overview",
      "Hours Breakdown", 
      "Project Cost & Estimation"
    ]

    if @cost_estimate.features.any?
      items.insert(1, "Feature Analysis")
    end

    y_position = page_height - page_height * 0.55
    items.each_with_index do |item, index|
      number = (index + 1).to_s.rjust(2, '0')
      
      pdf.font_size 19
      pdf.fill_color BLACK_COLOR
      pdf.text_box sanitize_text(number), 
        at: [33, y_position], 
        style: :bold,
        color: BLACK_COLOR

      pdf.font_size 20
      pdf.text_box sanitize_text(item), 
        at: [75, y_position], 
        color: BLACK_COLOR

      y_position -= 45
    end
  end

  def add_project_overview(pdf)
    page_height = pdf.bounds.height
    margin_top = page_height * 0.09

    # Page title
    add_page_title(pdf, "Project Overview", margin_top)

    current_y = page_height * 0.2

    # Overview section
    pdf.font_size 16
    pdf.fill_color BLACK_COLOR
    pdf.text_box sanitize_text("OVERVIEW"), 
      at: [30, current_y], 
      style: :bold,
      color: BLACK_COLOR

    # Project description with proper wrapping
    description_text = @cost_estimate.description || "No description provided"
    pdf.font_size 12
    
    # Calculate text height for proper spacing
    description_lines = description_text.length / 60 + 1 # Rough estimate
    description_height = description_lines * 15
    
    pdf.text_box sanitize_text(description_text), 
      at: [150, current_y], 
      width: 430,
      height: description_height,
      color: BLACK_COLOR

    current_y -= (description_height + 40)

    # Technical Information Section
    pdf.font_size 16
    pdf.fill_color BLACK_COLOR
    pdf.text_box sanitize_text("PROJECT SPECIFICATIONS"), 
      at: [30, current_y], 
      style: :bold,
      color: BLACK_COLOR

    current_y -= 30

    # Project specifications table
    specs = [
      ["Application Type", @cost_estimate.app_type_display],
      ["Project Scale", @cost_estimate.scale_display],
      ["Estimated Duration", "#{(@cost_estimate.total_hours / 40.0).ceil} weeks"],
      ["Total Development Hours", "#{@cost_estimate.total_hours} hours"],
      ["Hourly Rate", "$#{@cost_estimate.hourly_rate}/hour"],
      ["Total Investment", @cost_estimate.formatted_total_cost],
      ["Team Size", get_team_size_for_scale(@cost_estimate.scale)],
      ["Development Approach", get_development_approach(@cost_estimate.scale)]
    ]

    # Draw specifications table
    specs.each do |spec|
      # Label
      pdf.font_size 11
      pdf.fill_color GRAY_COLOR
      pdf.text_box sanitize_text("#{spec[0]}:"), 
        at: [30, current_y], 
        width: 120,
        style: :bold,
        color: GRAY_COLOR

      # Value
      pdf.font_size 12
      pdf.fill_color BLACK_COLOR
      pdf.text_box sanitize_text(spec[1]), 
        at: [160, current_y], 
        width: 400,
        color: BLACK_COLOR

      current_y -= 20
    end

    current_y -= 20

    # Feature Categories Summary
    if @cost_estimate.features.any?
      pdf.font_size 16
      pdf.fill_color BLACK_COLOR
      pdf.text_box sanitize_text("FEATURE CATEGORIES"), 
        at: [30, current_y], 
        style: :bold,
        color: BLACK_COLOR

      current_y -= 25

      grouped_features = @cost_estimate.features.group_by { |f| f['category'] || 'General' }
      
      grouped_features.each do |category, features|
        category_hours = features.sum { |f| f['hours'].to_i }
        
        # Category name
        pdf.font_size 12
        pdf.fill_color BLACK_COLOR
        pdf.text_box sanitize_text("• #{category}"), 
          at: [40, current_y], 
          width: 200,
          style: :bold,
          color: BLACK_COLOR

        # Feature count and hours
        pdf.text_box sanitize_text("#{features.count} features (#{category_hours}h)"), 
          at: [250, current_y], 
          width: 200,
          color: GRAY_COLOR

        current_y -= 18
      end
    end

    # Add footer
    add_page_footer(pdf)
  end

  def get_team_size_for_scale(scale)
    case scale
    when 'mvp'
      "2-3 developers"
    when 'moderate'
      "3-5 developers"
    when 'enterprise'
      "5-8 developers"
    else
      "3-4 developers"
    end
  end

  def get_development_approach(scale)
    case scale
    when 'mvp'
      "Agile methodology with rapid prototyping"
    when 'moderate'
      "Agile development with comprehensive testing"
    when 'enterprise'
      "Enterprise-grade development with extensive QA"
    else
      "Standard agile development process"
    end
  end

  def add_hours_breakdown(pdf)
    page_height = pdf.bounds.height
    margin_top = page_height * 0.09

    # Page title
    add_page_title(pdf, "Hours Breakdown", margin_top)

    # Table setup
    margin_top_overview = page_height * 0.15
    page_width = pdf.bounds.width
    horizontal_margin = 30
    table_width = page_width - 2 * horizontal_margin
    features_col_width = table_width * 0.8
    hours_col_width = table_width * 0.2
    row_height = 30
    font_size = 12
    y_position = page_height - margin_top_overview

    # Table header
    pdf.fill_color GRAY_COLOR
    pdf.fill_rectangle [horizontal_margin, y_position], table_width, row_height

    pdf.fill_color WHITE_COLOR
    pdf.font_size font_size
    pdf.text_box sanitize_text("Features"), 
      at: [horizontal_margin + 5, y_position - row_height/2 + font_size/2], 
      style: :bold,
      color: WHITE_COLOR

    pdf.text_box sanitize_text("Hours"), 
      at: [horizontal_margin + features_col_width + 5, y_position - row_height/2 + font_size/2], 
      style: :bold,
      color: WHITE_COLOR

    y_position -= row_height

    # Check if we need a new page for features
    def check_page_space(pdf, y_position, rows_needed, row_height, page_height, margin_top_overview, horizontal_margin, table_width, features_col_width, margin_top)
      space_needed = rows_needed * row_height + 100 # Footer space
      if y_position - space_needed < 100
        pdf.start_new_page
        
        # Recreate header on new page
        add_page_title(pdf, "Hours Breakdown (Continued)", margin_top)
        
        y_position = page_height - margin_top_overview
        
        # Table header
        pdf.fill_color GRAY_COLOR
        pdf.fill_rectangle [horizontal_margin, y_position], table_width, row_height

        pdf.fill_color WHITE_COLOR
        pdf.font_size 12
        pdf.text_box sanitize_text("Features"), 
          at: [horizontal_margin + 5, y_position - row_height/2 + 6], 
          style: :bold,
          color: WHITE_COLOR

        pdf.text_box sanitize_text("Hours"), 
          at: [horizontal_margin + features_col_width + 5, y_position - row_height/2 + 6], 
          style: :bold,
          color: WHITE_COLOR

        y_position -= row_height
      end
      y_position
    end

    # Features from AI analysis - show ALL individual features
    total_hours = 0
    grouped_features = @cost_estimate.features.group_by { |f| f['category'] || 'General' }
    
    grouped_features.each do |category, features|
      category_hours = features.sum { |f| f['hours'].to_i }
      total_hours += category_hours

      # Check if we need a new page (category + all features + total)
      rows_needed = 1 + features.count + 1 # Category header + features + separator
      y_position = check_page_space(pdf, y_position, rows_needed, row_height, page_height, margin_top_overview, horizontal_margin, table_width, features_col_width, margin_top)

      # Category header row with background
      pdf.fill_color LIGHT_GRAY
      pdf.fill_rectangle [horizontal_margin, y_position], table_width, row_height

      pdf.fill_color BLACK_COLOR
      pdf.stroke_color BLACK_COLOR
      pdf.line_width 1
      pdf.stroke_rectangle [horizontal_margin, y_position], table_width, row_height

      pdf.font_size font_size
      pdf.text_box sanitize_text("#{category.upcase} (#{features.count} features)"), 
        at: [horizontal_margin + 5, y_position - row_height/2 + font_size/2], 
        style: :bold,
        color: BLACK_COLOR

      pdf.text_box sanitize_text("#{category_hours}h"), 
        at: [horizontal_margin + features_col_width + 5, y_position - row_height/2 + font_size/2], 
        style: :bold,
        color: BLACK_COLOR

      y_position -= row_height

      # Individual features under each category
      features.each do |feature|
        feature_hours = feature['hours'].to_i
        
        pdf.fill_color WHITE_COLOR
        pdf.fill_rectangle [horizontal_margin, y_position], table_width, row_height
        
        pdf.stroke_color BLACK_COLOR
        pdf.line_width 1
        pdf.stroke_rectangle [horizontal_margin, y_position], table_width, row_height

        # Feature name (indented to show it's under category)
        pdf.fill_color BLACK_COLOR
        pdf.font_size 11
        feature_name = feature['name'] || 'Unnamed Feature'
        pdf.text_box sanitize_text("  • #{feature_name}"), 
          at: [horizontal_margin + 15, y_position - row_height/2 + font_size/2], 
          color: BLACK_COLOR

        pdf.text_box sanitize_text("#{feature_hours}h"), 
          at: [horizontal_margin + features_col_width + 5, y_position - row_height/2 + font_size/2], 
          color: BLACK_COLOR

        y_position -= row_height
      end

      # Add some spacing between categories
      y_position -= 5
    end

    # Check space for total row
    y_position = check_page_space(pdf, y_position, 1, row_height, page_height, margin_top_overview, horizontal_margin, table_width, features_col_width, margin_top)

    # Total row with emphasis
    pdf.fill_color GRAY_COLOR
    pdf.fill_rectangle [horizontal_margin, y_position], table_width, row_height

    pdf.stroke_color BLACK_COLOR
    pdf.line_width 2
    pdf.stroke_rectangle [horizontal_margin, y_position], table_width, row_height

    pdf.fill_color WHITE_COLOR
    pdf.font_size font_size
    pdf.text_box sanitize_text("TOTAL PROJECT HOURS"), 
      at: [horizontal_margin + 5, y_position - row_height/2 + font_size/2], 
      style: :bold,
      color: WHITE_COLOR

    pdf.text_box sanitize_text("#{total_hours}h"), 
      at: [horizontal_margin + features_col_width + 5, y_position - row_height/2 + font_size/2], 
      style: :bold,
      color: WHITE_COLOR

    # Vertical lines for the entire table
    start_y = page_height - margin_top_overview
    end_y = y_position

    pdf.stroke_line [horizontal_margin, start_y], [horizontal_margin, end_y]
    pdf.stroke_line [horizontal_margin + features_col_width, start_y], [horizontal_margin + features_col_width, end_y]
    pdf.stroke_line [horizontal_margin + table_width, start_y], [horizontal_margin + table_width, end_y]

    add_page_footer(pdf)
  end

  def add_feature_details(pdf)
    page_height = pdf.bounds.height
    margin_top = page_height * 0.09

    # Page title
    add_page_title(pdf, "Feature Specifications", margin_top)

    current_y = page_height * 0.2
    page_width = pdf.bounds.width
    horizontal_margin = 30

    grouped_features = @cost_estimate.features.group_by { |f| f['category'] || 'General' }
    
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
        at: [horizontal_margin, current_y], 
        style: :bold,
        color: BLACK_COLOR

      current_y -= 25

      # Features in this category
      features.each do |feature|
        feature_name = feature['name'] || 'Unnamed Feature'
        feature_description = feature['description'] || 'No description available'
        feature_hours = feature['hours'].to_i
        feature_complexity = feature['complexity'] || 'Medium'

        # Feature name and hours
        pdf.font_size 12
        pdf.fill_color BLACK_COLOR
        pdf.text_box sanitize_text("#{feature_name} (#{feature_hours}h)"), 
          at: [horizontal_margin + 10, current_y], 
          width: page_width - horizontal_margin - 150,
          style: :bold,
          color: BLACK_COLOR

        # Complexity badge
        complexity_color = case feature_complexity.downcase
                          when 'low' then '22C55E'    # Green
                          when 'medium' then 'F59E0B' # Amber  
                          when 'high' then 'EF4444'  # Red
                          else 'F59E0B'              # Default amber
                          end

        pdf.font_size 10
        pdf.fill_color complexity_color
        pdf.text_box sanitize_text(feature_complexity.upcase), 
          at: [page_width - 120, current_y], 
          width: 80,
          style: :bold,
          color: complexity_color

        current_y -= 18

        # Feature description
        pdf.font_size 11
        pdf.fill_color BLACK_COLOR
        
        # Calculate description height
        description_lines = feature_description.length / 80 + 1
        description_height = [description_lines * 14, 60].min # Max 60px height
        
        pdf.text_box sanitize_text(feature_description), 
          at: [horizontal_margin + 20, current_y], 
          width: page_width - horizontal_margin - 60,
          height: description_height,
          color: BLACK_COLOR

        current_y -= (description_height + 15)

        # Separator line
        pdf.stroke_color LIGHT_GRAY
        pdf.line_width 1
        pdf.stroke_line [horizontal_margin + 10, current_y], [page_width - horizontal_margin, current_y]
        
        current_y -= 10
      end

      current_y -= 20 # Space between categories
    end

    add_page_footer(pdf)
  end

  def add_cost_estimates(pdf)
    page_height = pdf.bounds.height
    margin_top = page_height * 0.09

    # Page title
    add_page_title(pdf, "Project Cost & Estimation", margin_top)

    # Table setup
    page_width = pdf.bounds.width
    margin = 100
    horizontal_margin = 30
    table_width = page_width - 2 * horizontal_margin
    col_width = table_width / 2
    row_height = 30
    font_size = 12
    y_position = page_height - margin

    # Calculate costs with breakdown
    hourly_rate = @cost_estimate.hourly_rate
    total_hours = @cost_estimate.total_hours
    total_cost = total_hours * hourly_rate
    
    # Calculate months (assuming 172 hours per month with 0.8 efficiency factor)
    monthly_hours = 172
    total_months = (total_hours.to_f / monthly_hours * 0.8).ceil

    # Calculate feature breakdown if available
    feature_breakdown = {}
    if @cost_estimate.features.any?
      grouped_features = @cost_estimate.features.group_by { |f| f['category'] || 'General' }
      grouped_features.each do |category, features|
        category_hours = features.sum { |f| f['hours'].to_i }
        feature_breakdown[category] = category_hours
      end
    end

    # Enhanced table data with feature breakdown
    table_data = [
      { label: "Project Duration", value: "#{total_months} months" },
      { label: "Total Hours", value: "#{total_hours} hours" },
      { label: "Hours Summary", value: "", is_header: true }
    ]

    # Add feature breakdown if available
    if feature_breakdown.any?
      feature_breakdown.each do |category, hours|
        table_data << { label: "#{category} Hours", value: "#{hours} hours" }
      end
    else
      table_data << { label: "Development Hours", value: "#{total_hours} hours" }
    end

    # Add rate and cost information
    table_data += [
      { label: "Hourly Rate (Industry Average)", value: "", is_header: true },
      { label: "Development Rate", value: "$#{hourly_rate}/hr" },
      { label: "Project Management", value: "Included" },
      { label: "Quality Assurance", value: "Included" },
      { label: "Documentation", value: "Included" },
      { label: "Total Project Cost (USD)", value: "$#{number_with_commas(total_cost.to_i)}", is_total: true }
    ]

    # Draw table
    table_data.each do |row|
      # Draw background for header row
      if row[:is_header]
        pdf.fill_color GRAY_COLOR
        pdf.fill_rectangle [horizontal_margin, y_position], table_width, row_height
      elsif row[:is_total]
        pdf.fill_color LIGHT_GRAY
        pdf.fill_rectangle [horizontal_margin, y_position], table_width, row_height
      end

      # Draw left column text
      text_color = if row[:is_header]
                     WHITE_COLOR
                   elsif row[:is_total]
                     BLACK_COLOR
                   else
                     BLACK_COLOR
                   end

      pdf.fill_color text_color
      pdf.font_size font_size
      font_style = (row[:is_header] || row[:is_total]) ? :bold : :normal
      
      pdf.text_box sanitize_text(row[:label]), 
        at: [horizontal_margin + 5, y_position - row_height/2 + font_size/2], 
        style: font_style,
        color: text_color

      # Draw right column text
      unless row[:value].empty?
        pdf.text_box sanitize_text(row[:value]), 
          at: [horizontal_margin + col_width + 5, y_position - row_height/2 + font_size/2], 
          style: font_style,
          color: text_color
      end

      # Draw horizontal line
      pdf.stroke_color BLACK_COLOR
      pdf.line_width 1
      pdf.stroke_line [horizontal_margin, y_position - row_height], [horizontal_margin + table_width, y_position - row_height]

      y_position -= row_height
    end

    # Draw vertical lines
    pdf.stroke_line [horizontal_margin, page_height - margin], [horizontal_margin, y_position + row_height]
    pdf.stroke_line [horizontal_margin + col_width, page_height - margin], [horizontal_margin + col_width, y_position + row_height]
    pdf.stroke_line [horizontal_margin + table_width, page_height - margin], [horizontal_margin + table_width, y_position + row_height]

    # Cost analysis section
    y_position -= 40
    
    pdf.font_size 14
    pdf.fill_color BLACK_COLOR
    pdf.text_box sanitize_text("COST ANALYSIS"), 
      at: [horizontal_margin, y_position], 
      style: :bold,
      color: BLACK_COLOR

    y_position -= 25

    # Cost breakdown insights
    pdf.font_size 11
    cost_insights = [
      "• Industry-competitive hourly rate of $#{hourly_rate}",
      "• Comprehensive development including QA and documentation",
      "• Estimated #{total_months}-month delivery timeline",
      "• Professional project management included"
    ]

    cost_insights.each do |insight|
      pdf.text_box sanitize_text(insight), 
        at: [horizontal_margin + 10, y_position], 
        width: table_width - 20,
        color: BLACK_COLOR

      y_position -= 15
    end

    # Bottom discount text
    discount_rate = 0.1
    discounted_cost = (total_cost * (1 - discount_rate)).to_i
    bottom_text = "Save 10% today and get the SAME app built with top-tier quality at Tecaudex for just $#{number_with_commas(discounted_cost)}"
    
    pdf.font_size 12
    pdf.fill_color RED_COLOR
    pdf.text_box sanitize_text(bottom_text), 
      at: [horizontal_margin, 130], 
      width: table_width - 60,
      style: :bold,
      color: RED_COLOR

    add_page_footer(pdf)
  end

  def add_page_title(pdf, title, margin_top)
    page_height = pdf.bounds.height
    
    pdf.font_size 24
    pdf.fill_color RED_COLOR
    pdf.text_box sanitize_text(title), 
      at: [30, page_height - margin_top], 
      style: :bold,
      color: RED_COLOR

    # Underline
    pdf.stroke_color RED_COLOR
    pdf.line_width 6
    pdf.stroke_line [30, page_height - margin_top + 30], [170, page_height - margin_top + 30]
  end

  def add_page_footer(pdf)
    footer_y = 40
    start_x = 50
    page_width = pdf.bounds.width
    content_width = page_width - (2 * start_x)
    
    # Subtle separator line
    pdf.stroke_color RED_COLOR
    pdf.line_width 1
    pdf.stroke_line [start_x, footer_y + 25], [start_x + content_width, footer_y + 25]

    # Footer sections
    section_width = content_width / 3
    label_size = 8
    value_size = 9

    # Customer data
    customer_name = @user&.name || "Valued Client"
    customer_phone = @user&.phone_number || "+1 (555) 123-4567"
    customer_email = @user&.email || "contact@tecaudex.com"

    # Name section
    pdf.font_size label_size
    pdf.fill_color GRAY_COLOR
    pdf.text_box sanitize_text("NAME"), 
      at: [start_x, footer_y + 8], 
      color: GRAY_COLOR

    pdf.font_size value_size
    pdf.fill_color BLACK_COLOR
    pdf.text_box sanitize_text(customer_name), 
      at: [start_x, footer_y - 8], 
      style: :bold,
      color: BLACK_COLOR

    # Contact section
    phone_x = start_x + section_width
    pdf.font_size label_size
    pdf.fill_color GRAY_COLOR
    pdf.text_box sanitize_text("CONTACT"), 
      at: [phone_x, footer_y + 8], 
      color: GRAY_COLOR

    pdf.font_size value_size
    pdf.fill_color BLACK_COLOR
    pdf.text_box sanitize_text(customer_phone), 
      at: [phone_x, footer_y - 8], 
      style: :bold,
      color: BLACK_COLOR

    # Email section
    email_x = start_x + (2 * section_width)
    pdf.font_size label_size
    pdf.fill_color GRAY_COLOR
    pdf.text_box sanitize_text("EMAIL"), 
      at: [email_x, footer_y + 8], 
      color: GRAY_COLOR

    pdf.font_size value_size
    pdf.fill_color BLACK_COLOR
    pdf.text_box sanitize_text(customer_email), 
      at: [email_x, footer_y - 8], 
      style: :bold,
      color: BLACK_COLOR

    # Dot separators
    [1, 2].each do |i|
      dot_x = start_x + (i * section_width) - 15
      pdf.fill_color GRAY_COLOR
      pdf.fill_circle [dot_x, footer_y], 1.5
    end
  end

  def number_with_commas(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end