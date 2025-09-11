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
    page_width = pdf.bounds.width

    # Page title (matching TypeScript "Project Crux")
    add_page_title(pdf, "Project Crux", margin_top)

    # Setup margins exactly like TypeScript
    margin_top_overview = page_height * 0.2

    # OVERVIEW section (exactly like TypeScript)
    pdf.fill_color BLACK_COLOR
    pdf.font_size 16
    pdf.text_box sanitize_text("OVERVIEW"), 
      at: [30, page_height - margin_top_overview], 
      style: :bold,
      color: BLACK_COLOR

    # Project description (matching TypeScript layout with drawWrappedText equivalent)
    description_text = @cost_estimate.description || "No description provided"
    pdf.font_size 12
    pdf.text_box sanitize_text(description_text), 
      at: [150, page_height - margin_top_overview], 
      width: 430,  # Match TypeScript width
      height: 100, # Allow for wrapping
      color: BLACK_COLOR,
      leading: 5

    # Calculate height used by description (approximate)
    description_height = (description_text.length / 70.0 * 20).ceil # Rough calculation

    # TECHNICAL INFORMATION section
    margin_top_technical_title = margin_top_overview + 30 + description_height
    pdf.fill_color BLACK_COLOR
    pdf.font_size 16
    pdf.text_box sanitize_text("TECHNICAL INFORMATION"), 
      at: [30, page_height - margin_top_technical_title], 
      style: :bold,
      color: BLACK_COLOR

    # Technical information content
    margin_top_technical_text = margin_top_technical_title + 30
    
    # Build technical summary based on cost estimate data
    tech_summary = build_technical_summary()
    
    pdf.font_size 12
    pdf.text_box sanitize_text(tech_summary), 
      at: [150, page_height - margin_top_technical_text], 
      width: 430,
      height: 200, # Allow for longer content
      color: BLACK_COLOR,
      leading: 5

    add_page_footer(pdf)
  end

  private

  def build_technical_summary
    summary_parts = []
    
    # Application type info
    summary_parts << "Application Type: #{@cost_estimate.app_type_display}"
    summary_parts << "Project Scale: #{@cost_estimate.scale_display}"
    
    # Development approach based on scale
    case @cost_estimate.scale
    when 'mvp'
      summary_parts << "Development Approach: Rapid prototyping with core functionality focus, agile methodology with 2-week sprints."
    when 'moderate'
      summary_parts << "Development Approach: Balanced development with comprehensive testing, agile methodology with full feature implementation."
    when 'enterprise'
      summary_parts << "Development Approach: Enterprise-grade architecture with extensive quality assurance, security protocols, and scalability planning."
    else
      summary_parts << "Development Approach: Standard agile development with industry best practices."
    end
    
    # Technology considerations
    if @cost_estimate.features.any?
      categories = @cost_estimate.features.map { |f| f['category'] }.uniq.compact
      summary_parts << "Key Technology Areas: #{categories.join(', ')}"
    end
    
    # Timeline and team info
    timeline_weeks = (@cost_estimate.total_hours / 40.0).ceil
    summary_parts << "Estimated Timeline: #{timeline_weeks} weeks with #{get_team_size_for_scale(@cost_estimate.scale)}"
    summary_parts << "Total Development Hours: #{@cost_estimate.total_hours} hours across all development phases"
    
    summary_parts.join(". ")
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
    page_width = pdf.bounds.width

    # Page title (exactly like TypeScript version)
    add_page_title(pdf, "Hours Breakdown", margin_top)

    # Setup table parameters (matching TypeScript)
    margin_top_overview = page_height * 0.15
    horizontal_margin = 30
    table_width = page_width - 2 * horizontal_margin
    features_col_width = table_width * 0.8  # 80% for Features
    hours_col_width = table_width * 0.2     # 20% for Hours
    row_height = 30
    font_size = 12
    y_position = page_height - margin_top_overview

    # Table header
    table_data = [{ label: 'Features', value: 'Hours', is_header: true }]

    # Add feature data to table (simple like TypeScript)
    grouped_features = @cost_estimate.features.group_by { |f| f['category'] || 'General' }
    total_hours = 0

    grouped_features.each do |category, features|
      category_hours = features.sum { |f| f['hours'].to_i }
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
        feature_name = feature['name'] || 'Unnamed Feature'
        feature_hours = feature['hours'].to_i
        
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
      label: 'Total Hours',
      value: "#{total_hours}h",
      is_header: false,
      is_total: true
    }

    # Draw table (exactly like TypeScript implementation)
    table_data.each_with_index do |row, index|
      # Check if we need a new page
      if y_position - row_height < 100
        pdf.start_new_page
        add_page_title(pdf, "Hours Breakdown (Continued)", margin_top)
        y_position = page_height - margin_top_overview
      end

      # Draw background for header row
      if row[:is_header]
        pdf.fill_color GRAY_COLOR
        pdf.fill_rectangle [horizontal_margin, y_position - row_height], table_width, row_height
      elsif row[:is_total]
        pdf.fill_color LIGHT_GRAY
        pdf.fill_rectangle [horizontal_margin, y_position - row_height], table_width, row_height
      end

      # Text color based on row type
      text_color = if row[:is_header]
                     WHITE_COLOR
                   else
                     BLACK_COLOR
                   end

      # Font style
      font_style = if row[:is_header] || row[:is_total] || row[:is_category]
                     :bold
                   else
                     :normal
                   end

      # Draw left column text (Features)
      pdf.fill_color text_color
      pdf.font_size font_size
      pdf.text_box sanitize_text(row[:label]), 
        at: [horizontal_margin + 5, y_position - row_height/2 + font_size/2], 
        width: features_col_width - 10,
        style: font_style,
        color: text_color

      # Draw right column text (Hours)
      pdf.text_box sanitize_text(row[:value]), 
        at: [horizontal_margin + features_col_width + 5, y_position - row_height/2 + font_size/2], 
        width: hours_col_width - 10,
        style: font_style,
        color: text_color

      # Draw horizontal line
      pdf.stroke_color BLACK_COLOR
      pdf.line_width 1
      pdf.stroke_line [horizontal_margin, y_position], [horizontal_margin + table_width, y_position]

      y_position -= row_height
    end

    # Draw bottom line
    pdf.stroke_line [horizontal_margin, y_position], [horizontal_margin + table_width, y_position]

    # Draw vertical lines (matching TypeScript)
    pdf.stroke_line [horizontal_margin, page_height - margin_top_overview], [horizontal_margin, y_position]
    pdf.stroke_line [horizontal_margin + features_col_width, page_height - margin_top_overview], [horizontal_margin + features_col_width, y_position]
    pdf.stroke_line [horizontal_margin + table_width, page_height - margin_top_overview], [horizontal_margin + table_width, y_position]

    add_page_footer(pdf)
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
        clean_match = match.first.to_s.strip.gsub(/^(and|with|or)\s+/i, '')
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