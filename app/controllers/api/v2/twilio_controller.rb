class Api::V2::TwilioController < Api::V2::BaseController
  # Generate a Twilio capability token
  def token
    begin
      # Use current user's ID or email as identity, or accept from params
      identity = params[:identity] || current_user&.id&.to_s || current_user&.email || 'mobile_user'

      token = twilio_service.generate_capability_token(identity)

      render_success({ token: token }, 'Token generated successfully')
    rescue => e
      Rails.logger.error("Error generating Twilio token: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render_error("Unable to generate calling token. Please try again later.", nil, :service_unavailable)
    end
  end

  private

  def twilio_service
    @twilio_service ||= TwilioService.new
  end
end