# Twilio configuration
# These environment variables should be set in your production environment
# For development, you can set them in your .env file or directly in this file

# Twilio Account SID and Auth Token
# Find these values in your Twilio Console: https://www.twilio.com/console
# if Rails.env.development? && ENV['TWILIO_ACCOUNT_SID'].blank?
#   # Default development values (replace with your actual Twilio credentials)
#   ENV['TWILIO_ACCOUNT_SID'] = 'your_twilio_account_sid'
#   ENV['TWILIO_AUTH_TOKEN'] = 'your_twilio_auth_token'
#
#   # TwiML Application SID
#   # Create a TwiML app in your Twilio Console and set the Voice URL to:
#   # https://your-app-url.com/twilio/voice
#   ENV['TWILIO_APP_SID'] = 'your_twilio_app_sid'
#
#   # Caller ID (must be a verified number in your Twilio account)
#   ENV['TWILIO_CALLER_ID'] = '+1234567890'
#
#   # Log a warning
#   Rails.logger.warn "Using placeholder Twilio credentials. Please set actual credentials in your environment."
# end
#
# # Validate that Twilio credentials are set
# unless ENV['TWILIO_ACCOUNT_SID'].present? &&
#        ENV['TWILIO_AUTH_TOKEN'].present? &&
#        ENV['TWILIO_APP_SID'].present? &&
#        ENV['TWILIO_CALLER_ID'].present?
#   Rails.logger.error "Missing Twilio credentials. Browser-based calling will not work."
# end