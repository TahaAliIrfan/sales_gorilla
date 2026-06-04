class AddLocationDataToCustomers < ActiveRecord::Migration[7.1]
  def change
    # Geographic location details
    add_column :customers, :state, :string
    add_column :customers, :city, :string
    add_column :customers, :area_code, :string
    add_column :customers, :geo_name, :string

    # Coordinates for precise timezone detection
    add_column :customers, :latitude, :decimal, precision: 10, scale: 6
    add_column :customers, :longitude, :decimal, precision: 10, scale: 6

    # Carrier and phone type information
    add_column :customers, :carrier, :string
    add_column :customers, :phone_type, :string

    # Timezone details
    add_column :customers, :timezone_offset, :decimal, precision: 4, scale: 2
    add_column :customers, :timezone_abbreviation, :string

    # Phone analysis metadata
    add_column :customers, :phone_analysis_completed_at, :datetime
    add_column :customers, :phone_analysis_version, :string, default: '1.0'

    # Add indexes for better query performance
    add_index :customers, :state
    add_index :customers, :city
    add_index :customers, :area_code
    add_index :customers, :carrier
    add_index :customers, [ :latitude, :longitude ], name: 'index_customers_on_coordinates'
    add_index :customers, :phone_analysis_completed_at
  end
end
