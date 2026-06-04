require "csv"

class CsvImportService
  attr_reader :csv_file, :errors

  def initialize(csv_file = nil)
    @csv_file = csv_file
    @errors = []
  end

  def parse_and_analyze
    return { error: "No CSV file provided" } unless @csv_file

    begin
      # Read and parse CSV
      csv_content = @csv_file.read.force_encoding("UTF-8")

      # Parse CSV with headers
      csv_data = CSV.parse(csv_content, headers: true, skip_blanks: true)

      if csv_data.empty?
        return { error: "CSV file is empty or has no data rows" }
      end

      headers = csv_data.headers
      sample_rows = csv_data.first(10).map(&:to_h) # Get first 10 rows as sample
      total_rows = csv_data.length

      # Suggest field mappings based on header names
      suggested_mappings = suggest_field_mappings(headers)

      {
        headers: headers,
        sample_rows: sample_rows,
        total_rows: total_rows,
        suggested_mappings: suggested_mappings
      }

    rescue CSV::MalformedCSVError => e
      { error: "Invalid CSV format: #{e.message}" }
    rescue => e
      Rails.logger.error "CSV Parse Error: #{e.message}"
      { error: "Error reading CSV file: #{e.message}" }
    end
  end

  def import_customers_from_upload(csv_upload, field_mappings, current_user)
    imported_count = 0
    skipped_count = 0
    errors = []

    begin
      # Read CSV content from file
      csv_content = csv_upload.read_csv_content
      csv_rows = CSV.parse(csv_content, headers: true, skip_blanks: true)

      csv_rows.each_with_index do |row, index|
        begin
          customer_attributes = map_row_to_customer_attributes(row, field_mappings)

          # Apply default lead source if no lead_source was mapped and upload has a default
          if customer_attributes[:lead_source].blank? && csv_upload.respond_to?(:lead_source) && csv_upload.lead_source.present?
            customer_attributes[:lead_source] = csv_upload.lead_source
          end

          # Skip rows that don't have required fields
          if customer_attributes[:name].blank?
            skipped_count += 1
            errors << "Row #{index + 2}: Name is required"
            next
          end

          # Check for existing customer by email or phone
          existing_customer = find_existing_customer(customer_attributes)

          if existing_customer
            # Update existing customer with new data
            if update_existing_customer(existing_customer, customer_attributes)
              imported_count += 1
            else
              skipped_count += 1
              errors << "Row #{index + 2}: #{existing_customer.errors.full_messages.join(', ')}"
            end
          else
            # Create new customer - customers are unassigned by default during CSV import
            customer = Customer.new(customer_attributes)
            # Do not assign to current_user - leave unassigned unless explicitly mapped

            if customer.save
              imported_count += 1
            else
              skipped_count += 1
              errors << "Row #{index + 2}: #{customer.errors.full_messages.join(', ')}"
            end
          end

        rescue => e
          skipped_count += 1
          errors << "Row #{index + 2}: #{e.message}"
        end
      end

      # Mark upload as completed
      csv_upload.update!(status: "completed")

      {
        success: true,
        imported_count: imported_count,
        skipped_count: skipped_count,
        errors: errors
      }

    rescue => e
      Rails.logger.error "CSV Import Error: #{e.message}"
      csv_upload.update!(status: "failed") if csv_upload.persisted?
      {
        success: false,
        error: e.message
      }
    end
  end

  def import_customers(csv_data, field_mappings, current_user)
    imported_count = 0
    skipped_count = 0
    errors = []

    begin
      # Re-read the original CSV file from session data
      # We'll need to implement a way to store and retrieve the full CSV data
      # For now, let's work with what we have

      csv_content = reconstruct_csv_from_session_data(csv_data)
      csv_rows = CSV.parse(csv_content, headers: true, skip_blanks: true)

      csv_rows.each_with_index do |row, index|
        begin
          customer_attributes = map_row_to_customer_attributes(row, field_mappings)

          # Skip rows that don't have required fields
          if customer_attributes[:name].blank?
            skipped_count += 1
            errors << "Row #{index + 2}: Name is required"
            next
          end

          # Check for existing customer by email or phone
          existing_customer = find_existing_customer(customer_attributes)

          if existing_customer
            # Update existing customer with new data
            if update_existing_customer(existing_customer, customer_attributes)
              imported_count += 1
            else
              skipped_count += 1
              errors << "Row #{index + 2}: #{existing_customer.errors.full_messages.join(', ')}"
            end
          else
            # Create new customer - customers are unassigned by default during CSV import
            customer = Customer.new(customer_attributes)
            # Do not assign to current_user - leave unassigned unless explicitly mapped

            if customer.save
              imported_count += 1
            else
              skipped_count += 1
              errors << "Row #{index + 2}: #{customer.errors.full_messages.join(', ')}"
            end
          end

        rescue => e
          skipped_count += 1
          errors << "Row #{index + 2}: #{e.message}"
        end
      end

      {
        success: true,
        imported_count: imported_count,
        skipped_count: skipped_count,
        errors: errors
      }

    rescue => e
      Rails.logger.error "CSV Import Error: #{e.message}"
      {
        success: false,
        error: e.message
      }
    end
  end

  private

  def suggest_field_mappings(headers)
    mappings = {}

    # Define mapping patterns for common field names
    field_patterns = {
      "name" => [ "name", "full name", "customer name", "client name", "contact name", "first name" ],
      "email" => [ "email", "email address", "e-mail", "mail" ],
      "phone" => [ "phone", "phone number", "mobile", "contact number", "tel", "telephone" ],
      "company" => [ "company", "organization", "business", "firm", "company name" ],
      "address" => [ "address", "location", "street address", "full address" ],
      "country" => [ "country", "nation" ],
      "state" => [ "state", "province", "region" ],
      "city" => [ "city", "town", "locality" ],
      "lead_source" => [ "lead source", "source", "origin", "channel" ],
      "status" => [ "status", "customer status", "lead status" ],
      "project_type" => [ "project type", "project", "service" ],
      "platform" => [ "platform", "technology" ],
      "linkedin_url" => [ "linkedin", "linkedin url", "linkedin profile" ],
      "notes" => [ "notes", "comments", "description", "details" ],
      "idea_description" => [ "idea", "project description", "requirements" ],
      "project_estimated_cost" => [ "cost", "budget", "estimated cost", "price" ]
    }

    headers.each do |header|
      next if header.blank?

      normalized_header = header.downcase.strip

      field_patterns.each do |field, patterns|
        if patterns.any? { |pattern| normalized_header.include?(pattern) }
          mappings[header] = field
          break
        end
      end
    end

    mappings
  end

  def map_row_to_customer_attributes(row, field_mappings)
    attributes = {}

    field_mappings.each do |csv_header, customer_field|
      next if customer_field.blank? || csv_header.blank?

      value = row[csv_header]
      next if value.blank?

      # Clean and process the value based on field type
      processed_value = process_field_value(customer_field, value)
      attributes[customer_field.to_sym] = processed_value if processed_value.present?
    end

    # Set default values for required dropdown fields
    set_default_dropdown_values(attributes)

    attributes
  end

  def process_field_value(field, value)
    return nil if value.blank?

    case field
    when "email"
      value.downcase.strip
    when "phone"
      # Normalize phone number
      cleaned = value.strip
      # Remove all non-digit characters except the plus sign
      digits_only = cleaned.gsub(/[^\d+]/, "")
      # Ensure it starts with + and has only digits after that
      if digits_only.start_with?("+")
        digits_only
      elsif digits_only.length > 0
        "+#{digits_only}"
      else
        nil
      end
    when "project_estimated_cost"
      # Extract numeric value from cost
      value.to_s.gsub(/[^\d.]/, "").to_f
    when "lead_source"
      # Map to valid lead source values
      map_to_valid_option(value, Customer::LEAD_SOURCES)
    when "status"
      map_to_valid_option(value, Customer::STATUSES)
    when "project_type"
      map_to_valid_option(value, Customer::PROJECT_TYPES)
    when "platform"
      map_to_valid_option(value, Customer::PLATFORMS)
    when "project_scope"
      map_to_valid_option(value, Customer::PROJECT_SCOPES)
    when "customer_type"
      map_to_valid_option(value, Customer::CUSTOMER_TYPES)
    when "upwork_profile"
      map_to_valid_option(value, Customer::UPWORK_PROFILES)
    else
      value.strip
    end
  end

  def map_to_valid_option(value, valid_options)
    return nil if value.blank?

    normalized_value = value.strip

    # Try exact match first
    return normalized_value if valid_options.values.include?(normalized_value)

    # Try case-insensitive match
    valid_options.values.each do |option|
      return option if option.downcase == normalized_value.downcase
    end

    # Try partial match
    valid_options.values.each do |option|
      return option if option.downcase.include?(normalized_value.downcase) ||
                      normalized_value.downcase.include?(option.downcase)
    end

    # Return original value if no match found (will be validated by model)
    normalized_value
  end

  def set_default_dropdown_values(attributes)
    # Set defaults for required fields that weren't mapped
    attributes[:customer_type] ||= "Standard"
    attributes[:status] ||= "Pending"
    attributes[:call_status] ||= "Pending"
    attributes[:email_status] ||= "Pending"
    attributes[:whatsapp_status] ||= "Pending"
    attributes[:linkedin_status] ||= "Pending"
    attributes[:project_type] ||= "Not Applicable"
    attributes[:platform] ||= "Not Applicable"
    attributes[:project_scope] ||= "Not Applicable"
    attributes[:upwork_profile] ||= "Not Applicable"
    attributes[:exhaust_status] ||= "NA"
  end

  def find_existing_customer(attributes)
    # Try to find by email first, then by phone
    if attributes[:email].present?
      customer = Customer.find_by(email: attributes[:email])
      return customer if customer
    end

    if attributes[:phone].present?
      Customer.find_by(phone: attributes[:phone])
    end
  end

  def update_existing_customer(customer, new_attributes)
    # Only update fields that are blank in existing customer or explicitly different
    update_attributes = {}

    new_attributes.each do |key, value|
      next if value.blank?

      current_value = customer.send(key)

      # Update if current value is blank or if it's a non-critical field
      if current_value.blank? || updatable_field?(key)
        update_attributes[key] = value
      end
    end

    return true if update_attributes.empty?

    customer.update(update_attributes)
  end

  def updatable_field?(field)
    # Fields that can be safely updated even if they already have values
    updatable_fields = [
      :notes, :idea_description, :address, :country, :state, :city,
      :linkedin_url, :ccr_link, :lead_source
    ]

    updatable_fields.include?(field.to_sym)
  end

  def reconstruct_csv_from_session_data(csv_data)
    # Use the stored CSV content if available
    if csv_data["csv_content"].present?
      Rails.logger.info "Using full CSV content from session (#{csv_data['csv_content'].length} characters)"
      return csv_data["csv_content"]
    end

    # Fallback to reconstructing from sample data (limited functionality)
    Rails.logger.warn "CSV content not found in session, falling back to sample data reconstruction"
    headers = csv_data["headers"]
    sample_rows = csv_data["sample_rows"]

    Rails.logger.info "Reconstructing CSV from #{sample_rows.length} sample rows (this will limit import to sample data only)"

    csv_string = CSV.generate do |csv|
      csv << headers
      sample_rows.each do |row|
        csv << headers.map { |header| row[header] }
      end
    end

    csv_string
  end

  # Get all available customer fields for mapping
  def self.available_customer_fields
    {
      "name" => "Name (Required)",
      "email" => "Email",
      "phone" => "Phone",
      "company" => "Company",
      "address" => "Address",
      "country" => "Country",
      "state" => "State/Province",
      "city" => "City",
      "lead_source" => "Lead Source",
      "status" => "Status",
      "customer_type" => "Customer Type",
      "project_type" => "Project Type",
      "platform" => "Platform",
      "project_scope" => "Project Scope",
      "linkedin_url" => "LinkedIn URL",
      "ccr_link" => "CCR Link",
      "upwork_profile" => "Upwork Profile",
      "notes" => "Notes",
      "idea_description" => "Project Description",
      "project_estimated_cost" => "Estimated Cost"
    }
  end
end
