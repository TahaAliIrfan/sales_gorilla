class BackfillTranscriptionFeature < ActiveRecord::Migration[7.1]
  class MigrationOrganizationFeature < ActiveRecord::Base
    self.table_name = "organization_features"
    encrypts :settings
    serialize :settings, coder: JSON, type: Hash
  end

  def up
    deepgram_key = Rails.application.credentials.dig(:DEEPGRAM_API)

    Organization.find_each do |org|
      next if MigrationOrganizationFeature.exists?(organization_id: org.id, key: "transcription")

      MigrationOrganizationFeature.create!(
        organization_id: org.id,
        key: "transcription",
        enabled: deepgram_key.present?,
        provider: deepgram_key.present? ? "deepgram" : nil,
        settings: deepgram_key.present? ? { "api_key" => deepgram_key } : {}
      )
    end
  end

  def down
    MigrationOrganizationFeature.where(key: "transcription").delete_all
  end
end
