module ApplicationCable
  # WebSocket clients (mobile apps) authenticate the same way they hit the API:
  # by passing the JWT we issue from Api::V2::AuthenticationController#login.
  #
  # The token is read from the `?token=` query string (the standard pattern for
  # WebSocket clients, which can't set Authorization headers cleanly).
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      token = request.params[:token].to_s
      reject_unauthorized_connection if token.blank?

      decoded = JsonWebToken.decode(token)
      User.find(decoded[:user_id])
    rescue StandardError => e
      Rails.logger.warn("[ActionCable] auth rejected: #{e.class} #{e.message}")
      reject_unauthorized_connection
    end
  end
end
