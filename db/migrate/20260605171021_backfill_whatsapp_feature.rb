class BackfillWhatsappFeature < ActiveRecord::Migration[7.1]
  class MigrationOrganizationFeature < ActiveRecord::Base
    self.table_name = "organization_features"
    encrypts :settings
    serialize :settings, coder: JSON, type: Hash
  end

  # Default WhatsApp sender that's been hardcoded in TwilioWhatsappService
  # (FROM = "whatsapp:+13022067878"). Each org now configures its own; for
  # the first migration we copy the shared one onto every existing org so
  # nothing breaks while admins set up per-org senders later.
  LEGACY_DEFAULT_SENDER = "+13022067878".freeze

  def up
    creds = Rails.application.credentials
    account_sid = creds.dig(:TWILIO_ACCOUNT_SID)
    auth_token = creds.dig(:TWILIO_AUTH_TOKEN)
    has_creds = account_sid.present? && auth_token.present?

    settings = {
      "account_sid" => account_sid,
      "auth_token" => auth_token,
      "sender_number" => LEGACY_DEFAULT_SENDER,
      "app_url" => "https://crm.tecaudex.com"
    }.compact

    Organization.find_each do |org|
      next if MigrationOrganizationFeature.exists?(organization_id: org.id, key: "whatsapp")

      MigrationOrganizationFeature.create!(
        organization_id: org.id,
        key: "whatsapp",
        enabled: has_creds,
        provider: has_creds ? "twilio" : nil,
        settings: settings
      )
    end
  end

  def down
    MigrationOrganizationFeature.where(key: "whatsapp").delete_all
  end
end
