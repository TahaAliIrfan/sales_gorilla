class Api::V2::AuthenticationController < Api::V2::BaseController
  skip_before_action :authenticate_request, only: [:login, :google_sign_in]

  def login
    user = User.find_by(email: params[:email])
    
    if user
      token = JsonWebToken.encode(user_id: user.id)
      render_success(
        { 
          token: token, 
          user: {
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.highest_role&.key || 'associate'
          }
        }, 
        'Login successful'
      )
    else
      render_error('Invalid credentials', nil, :unauthorized)
    end
  end

  def google_sign_in
    # Verify Google ID token
    id_token = params[:id_token]
    
    if id_token.blank?
      return render_error('Google ID token is required', nil, :bad_request)
    end

    begin
      # Verify the Google ID token
      payload = verify_google_token(id_token)
      
      if payload.nil?
        return render_error('Invalid Google token', nil, :unauthorized)
      end

      # Find or create user based on Google info
      user = User.find_or_create_by(provider: 'google_oauth2', uid: payload['sub']) do |u|
        u.name = payload['name']
        u.email = payload['email']
      end

      # Check if user email is authorized
      admin_emails = ['sarmad.mansoor@tecaudex.com', 'taha.irfan@tecaudex.com', 'arham.anwaar@tecaudex.com']
      allowed_emails = ['ifrah.khurram97@gmail.com', 'tahairfan1993@gmail.com']
      
      unless user.email.ends_with?('@tecaudex.com') || allowed_emails.include?(user.email.downcase)
        return render_error('Access restricted to authorized email addresses', nil, :forbidden)
      end

      # Assign admin role to specific users if not already assigned
      if admin_emails.include?(user.email.downcase) && !user.admin?
        user.make_admin!
      end

      # Generate JWT token for mobile app
      token = JsonWebToken.encode(user_id: user.id)
      
      render_success(
        { 
          token: token, 
          user: {
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.highest_role&.key || 'associate',
            phone: user.phone_number
          }
        }, 
        'Google sign-in successful'
      )
    rescue => e
      Rails.logger.error "Google sign-in error: #{e.message}"
      render_error('Authentication failed', e.message, :unauthorized)
    end
  end

  def logout
    render_success(nil, 'Logged out successfully')
  end

  def profile
    render_success({
      id: current_user.id,
      name: current_user.name,
      email: current_user.email,
      role: current_user.highest_role&.key || 'associate',
      phone: current_user.phone_number
    })
  end

  private

  def verify_google_token(id_token)
    require 'net/http'
    require 'json'
    
    # Use Google's tokeninfo endpoint to verify the token
    uri = URI("https://oauth2.googleapis.com/tokeninfo?id_token=#{id_token}")
    response = Net::HTTP.get_response(uri)
    
    if response.is_a?(Net::HTTPSuccess)
      payload = JSON.parse(response.body)
      
      # Get valid client IDs for current environment
      valid_client_ids = FirebaseConfig.all_client_ids
      
      # Verify the token is for one of our apps
      token_audience = payload['aud']
      if FirebaseConfig.valid_client_id?(token_audience)
        Rails.logger.info "Google token verified for client: #{token_audience}"
        return payload
      else
        Rails.logger.error "Token audience mismatch: expected one of #{valid_client_ids}, got #{token_audience}"
        return nil
      end
    else
      Rails.logger.error "Google token verification failed: #{response.body}"
      return nil
    end
  rescue => e
    Rails.logger.error "Error verifying Google token: #{e.message}"
    return nil
  end
end