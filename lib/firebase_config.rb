class FirebaseConfig
  class << self
    def android_client_id(environment = Rails.env)
      Rails.application.credentials.dig(:firebase, environment.to_sym, :android_client_id)
    end

    def ios_client_id(environment = Rails.env)
      Rails.application.credentials.dig(:firebase, environment.to_sym, :ios_client_id)
    end

    def all_client_ids(environment = Rails.env)
      firebase_config = Rails.application.credentials.dig(:firebase, environment.to_sym)
      [
        Rails.application.credentials.dig(:GOOGLE_CLIENT_ID), # Legacy web client ID
        firebase_config&.dig(:android_client_id),             # Firebase Android
        firebase_config&.dig(:ios_client_id)                  # Firebase iOS
      ].compact
    end

    def valid_client_id?(client_id, environment = Rails.env)
      all_client_ids(environment).include?(client_id)
    end
  end
end
