class CreateCustomerLocations < ActiveRecord::Migration[7.1]
  def up
    # Only create the table if it doesn't already exist (production safety)
    unless table_exists?(:customer_locations)
      create_table :customer_locations do |t|
        # Foreign key
        t.references :customer, null: false, foreign_key: true, index: { unique: true }
        
        # Basic phone information
        t.string :formatted_number
        t.string :national_format
        t.string :country_code
        t.string :area_code
        t.string :phone_type
        
        # Geographic information
        t.string :country_iso
        t.string :country_name
        t.string :state_province
        t.string :city
        t.string :region
        t.string :geo_name
        
        # Coordinates for precise location
        t.decimal :latitude, precision: 10, scale: 6
        t.decimal :longitude, precision: 10, scale: 6
        
        # Timezone information
        t.string :timezone
        t.string :timezone_abbreviation
        t.decimal :timezone_offset, precision: 4, scale: 2
        t.boolean :dst_active, default: false
        t.string :preferred_calling_time
        
        # Carrier information
        t.string :carrier
        t.string :line_type
        t.string :network_operator
        
        # Analysis metadata
        t.string :analysis_version, default: '2.0'
        t.datetime :analyzed_at
        t.string :data_source
        t.json :raw_analysis_data
        t.integer :location_confidence, default: 0
        t.integer :timezone_confidence, default: 0

        t.timestamps
      end
      
      # Add indexes for better performance
      add_index :customer_locations, :country_iso
      add_index :customer_locations, :state_province
      add_index :customer_locations, :city
      add_index :customer_locations, :area_code
      add_index :customer_locations, :carrier
      add_index :customer_locations, [:latitude, :longitude], name: 'index_customer_locations_on_coordinates'
      add_index :customer_locations, :timezone
      add_index :customer_locations, :analyzed_at
      add_index :customer_locations, :analysis_version
      
      say "Created customer_locations table with all indexes"
    else
      say "customer_locations table already exists, skipping creation"
    end
  end

  def down
    # Only drop if it exists
    if table_exists?(:customer_locations)
      drop_table :customer_locations
      say "Dropped customer_locations table"
    else
      say "customer_locations table does not exist, skipping drop"
    end
  end
end
