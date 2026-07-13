class AddTemplateToCampaigns < ActiveRecord::Migration[7.1]
  def change
    # Campaigns now send an approved Twilio/Meta WhatsApp template rather than a
    # free-form green-api message. content_sid points at the approved template;
    # content_variables maps each template variable to a value (which may itself
    # contain {{customer_name}}-style tokens resolved per recipient).
    add_column :campaigns, :content_sid, :string
    add_column :campaigns, :content_variables, :jsonb, null: false, default: {}
  end
end
