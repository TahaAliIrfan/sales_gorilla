class Api::V2::AuthenticationController < Api::V2::BaseController
  skip_before_action :authenticate_request, only: [:login]

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

  def logout
    render_success(nil, 'Logged out successfully')
  end

  def profile
    render_success({
      id: current_user.id,
      name: current_user.name,
      email: current_user.email,
      role: current_user.highest_role&.key || 'associate',
      phone: current_user.phone,
      timezone: current_user.timezone
    })
  end
end