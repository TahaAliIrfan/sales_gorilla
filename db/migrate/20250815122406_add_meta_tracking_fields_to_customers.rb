class AddMetaTrackingFieldsToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :meta_lead_id, :string
    add_column :customers, :facebook_click_id, :string
    add_column :customers, :browser_id, :string
    add_column :customers, :meta_campaign_id, :string
    add_column :customers, :meta_adset_id, :string
    add_column :customers, :meta_ad_id, :string
    add_column :customers, :meta_events_sent, :text # JSON array of sent events
    add_column :customers, :last_meta_event_sent_at, :datetime
    
    # Add indexes for Meta tracking fields
    add_index :customers, :meta_lead_id
    add_index :customers, :facebook_click_id
    add_index :customers, :browser_id
  end
end
