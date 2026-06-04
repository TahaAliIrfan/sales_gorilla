class PopulateMetaMappings < ActiveRecord::Migration[7.1]
  class MigrationOrganizationFeature < ActiveRecord::Base
    self.table_name = "organization_features"
    encrypts :settings
    serialize :settings, coder: JSON, type: Hash
  end

  # Populate the new mapping keys on existing meta_conversions rows. Defaults
  # mirror today's hardcoded behavior so no event changes when this lands.
  def up
    MigrationOrganizationFeature.where(key: "meta_conversions").find_each do |f|
      settings = f.settings || {}
      changed = false

      unless settings.key?("customer_status_mappings")
        settings["customer_status_mappings"] = OrganizationFeature::META_DEFAULT_CUSTOMER_STATUS_MAPPINGS
        changed = true
      end

      # deal_stage_mappings keyed by deal_stage_id. Cannot pre-populate
      # without knowing which stages exist per org, so leave empty; admins
      # configure in Settings > Features.
      unless settings.key?("deal_stage_mappings")
        settings["deal_stage_mappings"] = {}
        changed = true
      end

      unless settings.key?("source_action_sources")
        settings["source_action_sources"] = OrganizationFeature::META_DEFAULT_SOURCE_ACTION_SOURCES
        changed = true
      end

      f.update!(settings: settings) if changed
    end
  end

  def down
    MigrationOrganizationFeature.where(key: "meta_conversions").find_each do |f|
      settings = f.settings || {}
      %w[customer_status_mappings deal_stage_mappings source_action_sources].each { |k| settings.delete(k) }
      f.update!(settings: settings)
    end
  end
end
