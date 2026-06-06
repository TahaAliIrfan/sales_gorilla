class MigrateCustomerLocationData < ActiveRecord::Migration[7.1]
  def up
    # Migrate existing phone analysis data from customers to customer_locations
    say "Migrating existing phone analysis data to customer_locations table..."
    
    migrated_count = 0
    failed_count = 0
    
    Customer.where.not(phone_analysis_completed_at: nil).find_each do |customer|
      begin
        # Create customer_location record from existing customer data
        CustomerLocation.create!(
          customer: customer,
          
          # Basic phone information (might be missing)
          formatted_number: customer.phone,
          country_code: customer.country_code,
          area_code: customer.area_code,
          phone_type: customer.phone_type,
          
          # Geographic information
          country_iso: customer.country,
          city: customer.city,
          state_province: customer.state,
          geo_name: customer.geo_name,
          latitude: customer.latitude,
          longitude: customer.longitude,
          
          # Timezone information
          timezone: customer.timezone,
          timezone_abbreviation: customer.timezone_abbreviation,
          timezone_offset: customer.timezone_offset,
          preferred_calling_time: customer.preferred_calling_time,
          
          # Carrier information
          carrier: customer.carrier,
          line_type: customer.phone_type,
          
          # Analysis metadata
          analysis_version: customer.phone_analysis_version || '1.0',
          analyzed_at: customer.phone_analysis_completed_at || customer.updated_at,
          data_source: 'migrated_from_customer_table',
          location_confidence: calculate_location_confidence_for_migration(customer),
          timezone_confidence: calculate_timezone_confidence_for_migration(customer)
        )
        
        migrated_count += 1
      rescue => e
        say "Failed to migrate customer #{customer.id}: #{e.message}"
        failed_count += 1
      end
    end
    
    say "Migration completed. Migrated: #{migrated_count}, Failed: #{failed_count}"
  end

  def down
    # Remove all customer_locations created during migration
    say "Removing migrated customer location data..."
    CustomerLocation.where(data_source: 'migrated_from_customer_table').delete_all
    say "Customer location migration reversed."
  end

  private

  def calculate_location_confidence_for_migration(customer)
    confidence = 0
    
    # Base confidence from phone number
    confidence += 30 if customer.phone.present?
    
    # Country identification
    confidence += 20 if customer.country.present?
    
    # Geographic specificity
    confidence += 15 if customer.state.present?
    confidence += 15 if customer.city.present?
    confidence += 10 if customer.area_code.present?
    confidence += 10 if customer.latitude.present? && customer.longitude.present?
    
    [confidence, 100].min
  end

  def calculate_timezone_confidence_for_migration(customer)
    confidence = 0
    
    # Base timezone presence
    confidence += 40 if customer.timezone.present?
    
    # Precision indicators
    confidence += 30 if customer.latitude.present? && customer.longitude.present?
    confidence += 20 if customer.timezone_offset.present?
    confidence += 10 if customer.preferred_calling_time.present? && customer.preferred_calling_time != 'Not Applicable'
    
    [confidence, 100].min
  end
end
