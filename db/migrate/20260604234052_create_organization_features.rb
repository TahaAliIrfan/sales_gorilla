class CreateOrganizationFeatures < ActiveRecord::Migration[7.1]
  # Phantom record so we can write encrypted columns without polluting the
  # global namespace with a "real" model class during the migration.
  class MigrationOrganizationFeature < ActiveRecord::Base
    self.table_name = "organization_features"
    encrypts :settings
    serialize :settings, coder: JSON, type: Hash
  end

  def up
    create_table :organization_features do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :key, null: false
      t.boolean :enabled, null: false, default: false
      t.string :provider
      t.text :settings

      t.timestamps
    end

    add_index :organization_features, [ :organization_id, :key ], unique: true

    # Backfill: enable Calling for every existing organization using the
    # currently-shared Twilio credentials from Rails credentials. Once each
    # org configures their own credentials via Settings > Features, the
    # shared credentials can be removed (see step 8 of the ERP refactor plan).
    creds = Rails.application.credentials
    shared_twilio_config = {
      "account_sid" => creds.dig(:TWILIO_ACCOUNT_SID),
      "auth_token" => creds.dig(:TWILIO_AUTH_TOKEN),
      "api_key" => creds.dig(:TWILIO_API_KEY),
      "api_secret" => creds.dig(:TWILIO_API_SECRET),
      "application_sid" => creds.dig(:TWILIO_APP_SID),
      "default_caller_id" => "+447897021964"
    }.compact

    Organization.find_each do |org|
      MigrationOrganizationFeature.create!(
        organization_id: org.id,
        key: "calling",
        enabled: shared_twilio_config["account_sid"].present?,
        provider: "twilio",
        settings: shared_twilio_config
      )
    end
  end

  def down
    drop_table :organization_features
  end
end
