class AddAdTrackingFieldsToCustomers < ActiveRecord::Migration[7.1]
  def change
    # Ad click tracking fields (using larger limit for click IDs as they can be long)
    add_column :customers, :gclid, :string, limit: 512
    add_column :customers, :gbraid, :string, limit: 512
    add_column :customers, :wbraid, :string, limit: 512
    add_column :customers, :fbclid, :string, limit: 512
    add_column :customers, :msclkid, :string, limit: 512

    # UTM parameters (utm_campaign and utm_term already exist from previous migration)
    add_column :customers, :utm_source, :string, limit: 255
    add_column :customers, :utm_medium, :string, limit: 255
    add_column :customers, :utm_content, :string, limit: 255

    # Landing page and traffic source
    add_column :customers, :landing_page, :text
    add_column :customers, :traffic_source, :string, limit: 255

    # Lead quality fields for Google Offline Conversions
    add_column :customers, :lead_quality, :string
    add_column :customers, :lead_quality_marked_at, :datetime
    add_column :customers, :lead_quality_marked_by_id, :bigint
    add_column :customers, :google_conversion_sent_at, :datetime
    add_column :customers, :google_conversion_status, :string

    # Add index for gclid lookups (common query for conversion tracking)
    add_index :customers, :gclid
    add_index :customers, :lead_quality
    add_index :customers, :google_conversion_status

    # Add foreign key for lead_quality_marked_by
    add_foreign_key :customers, :users, column: :lead_quality_marked_by_id
  end
end
