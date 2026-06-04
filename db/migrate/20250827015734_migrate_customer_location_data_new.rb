class MigrateCustomerLocationDataNew < ActiveRecord::Migration[7.1]
  def up
    # Safety check: only proceed if customer_locations table exists
    unless table_exists?(:customer_locations)
      say "customer_locations table does not exist, skipping migration"
      return
    end

    # Safety check: skip if migration already appears to have run
    existing_migrated_records = CustomerLocation.where(data_source: 'migrated_from_customer_table').count
    if existing_migrated_records > 0
      say "Found #{existing_migrated_records} already migrated records, skipping to avoid duplicates"
      return
    end

    # Migrate existing phone analysis data from customers to customer_locations
    say "Migrating existing phone analysis data to customer_locations table..."

    migrated_count = 0
    failed_count = 0

    customers_to_migrate = Customer.where.not(phone_analysis_completed_at: nil)
    total_customers = customers_to_migrate.count

    say "Found #{total_customers} customers with phone analysis data to migrate"

    customers_to_migrate.find_each.with_index do |customer, index|
      # Skip if customer already has a location record
      if customer.customer_location.present?
        say "Customer #{customer.id} already has location record, skipping"
        next
      end

      begin
        # Create customer_location record from existing customer data
        CustomerLocation.create!(
          customer: customer,

          # Basic phone information (might be missing)
          formatted_number: customer.phone,
          country_code: customer.respond_to?(:country_code) ? customer.country_code : nil,
          area_code: customer.respond_to?(:area_code) ? customer.area_code : nil,
          phone_type: customer.respond_to?(:phone_type) ? customer.phone_type : nil,

          # Geographic information
          country_iso: customer.respond_to?(:country) ? customer.country : nil,
          city: customer.respond_to?(:city) ? customer.city : nil,
          state_province: customer.respond_to?(:state) ? customer.state : nil,
          geo_name: customer.respond_to?(:geo_name) ? customer.geo_name : nil,
          latitude: customer.respond_to?(:latitude) ? customer.latitude : nil,
          longitude: customer.respond_to?(:longitude) ? customer.longitude : nil,

          # Timezone information
          timezone: customer.respond_to?(:timezone) ? customer.timezone : nil,
          timezone_abbreviation: customer.respond_to?(:timezone_abbreviation) ? customer.timezone_abbreviation : nil,
          timezone_offset: customer.respond_to?(:timezone_offset) ? customer.timezone_offset : nil,
          preferred_calling_time: customer.preferred_calling_time,

          # Carrier information
          carrier: customer.respond_to?(:carrier) ? customer.carrier : nil,
          line_type: customer.respond_to?(:phone_type) ? customer.phone_type : nil,

          # Analysis metadata
          analysis_version: customer.respond_to?(:phone_analysis_version) ? (customer.phone_analysis_version || '1.0') : '1.0',
          analyzed_at: customer.phone_analysis_completed_at || customer.updated_at,
          data_source: 'migrated_from_customer_table',
          location_confidence: calculate_location_confidence_for_migration(customer),
          timezone_confidence: calculate_timezone_confidence_for_migration(customer)
        )

        migrated_count += 1

        # Progress reporting every 100 records
        if (index + 1) % 100 == 0
          say "Migrated #{migrated_count} of #{total_customers} customers..."
        end

      rescue => e
        say "Failed to migrate customer #{customer.id}: #{e.message}"
        failed_count += 1

        # Stop if too many failures (more than 10% failure rate after first 50)
        if index > 50 && failed_count.to_f / (index + 1) > 0.1
          say "ERROR: High failure rate detected (#{failed_count}/#{index + 1}), stopping migration"
          raise "Migration aborted due to high failure rate"
        end
      end
    end

    say "Migration completed. Migrated: #{migrated_count}, Failed: #{failed_count}"

    if failed_count > 0
      say "WARNING: #{failed_count} customers failed to migrate. Check logs for details."
    end
  end

  def down
    # Remove all customer_locations created during this migration
    say "Removing migrated customer location data..."
    deleted_count = CustomerLocation.where(data_source: 'migrated_from_customer_table').delete_all
    say "Customer location migration reversed. Deleted #{deleted_count} records."
  end

  private

  def calculate_location_confidence_for_migration(customer)
    confidence = 0

    # Base confidence from phone number
    confidence += 30 if customer.phone.present?

    # Country identification
    confidence += 20 if customer.respond_to?(:country) && customer.country.present?

    # Geographic specificity
    confidence += 15 if customer.respond_to?(:state) && customer.state.present?
    confidence += 15 if customer.respond_to?(:city) && customer.city.present?
    confidence += 10 if customer.respond_to?(:area_code) && customer.area_code.present?
    confidence += 10 if customer.respond_to?(:latitude) && customer.respond_to?(:longitude) &&
                        customer.latitude.present? && customer.longitude.present?

    [ confidence, 100 ].min
  end

  def calculate_timezone_confidence_for_migration(customer)
    confidence = 0

    # Base timezone presence
    confidence += 40 if customer.respond_to?(:timezone) && customer.timezone.present?

    # Precision indicators
    confidence += 30 if customer.respond_to?(:latitude) && customer.respond_to?(:longitude) &&
                        customer.latitude.present? && customer.longitude.present?
    confidence += 20 if customer.respond_to?(:timezone_offset) && customer.timezone_offset.present?
    confidence += 10 if customer.preferred_calling_time.present? && customer.preferred_calling_time != 'Not Applicable'

    [ confidence, 100 ].min
  end
end
