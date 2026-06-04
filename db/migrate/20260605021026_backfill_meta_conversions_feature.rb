class BackfillMetaConversionsFeature < ActiveRecord::Migration[7.1]
  class MigrationOrganizationFeature < ActiveRecord::Base
    self.table_name = "organization_features"
    encrypts :settings
    serialize :settings, coder: JSON, type: Hash
  end

  def up
    creds = Rails.application.credentials
    pixel_id = creds.dig(:META_PIXEL_ID)
    access_token = creds.dig(:META_ACCESS_TOKEN)
    has_creds = pixel_id.present? && access_token.present?

    default_settings = {
      "pixel_id" => pixel_id,
      "access_token" => access_token,
      "test_event_code" => nil,
      "events_enabled" => OrganizationFeature::META_DEFAULT_EVENTS,
      "eligible_sources" => OrganizationFeature::META_DEFAULT_ELIGIBLE_SOURCES
    }.compact

    Organization.find_each do |org|
      next if MigrationOrganizationFeature.exists?(organization_id: org.id, key: "meta_conversions")

      MigrationOrganizationFeature.create!(
        organization_id: org.id,
        key: "meta_conversions",
        enabled: has_creds,
        provider: has_creds ? "meta" : nil,
        settings: default_settings
      )
    end
  end

  def down
    MigrationOrganizationFeature.where(key: "meta_conversions").delete_all
  end
end
