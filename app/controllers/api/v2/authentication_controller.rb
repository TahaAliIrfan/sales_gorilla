class Api::V2::AuthenticationController < Api::V2::BaseController
  skip_before_action :authenticate_request,    only: %i[login google_sign_in]
  skip_before_action :resolve_current_tenant,  only: %i[login google_sign_in logout]

  def login
    user = User.find_by(email: params[:email])

    if user
      ensure_membership_in_default_org(user)
      token = JsonWebToken.encode(user_id: user.id)
      render_success(
        {
          token: token,
          user: user_payload(user),
          organizations: organizations_payload(user)
        },
        "Login successful"
      )
    else
      render_error("Invalid credentials", nil, :unauthorized)
    end
  end

  def google_sign_in
    id_token = params[:id_token]
    return render_error("Google ID token is required", nil, :bad_request) if id_token.blank?

    begin
      payload = verify_google_token(id_token)
      return render_error("Invalid Google token", nil, :unauthorized) if payload.nil?

      user = User.find_or_create_by(provider: "google_oauth2", uid: payload["sub"]) do |u|
        u.name  = payload["name"]
        u.email = payload["email"]
      end

      admin_emails   = [ "sarmad.mansoor@tecaudex.com", "taha.irfan@tecaudex.com", "arham.anwaar@tecaudex.com" ]
      allowed_emails = [ "ifrah.khurram97@gmail.com", "tahairfan1993@gmail.com" ]

      unless user.email.ends_with?("@tecaudex.com") || allowed_emails.include?(user.email.downcase)
        return render_error("Access restricted to authorized email addresses", nil, :forbidden)
      end

      if admin_emails.include?(user.email.downcase) && !user.admin?
        user.make_admin!
      end

      ensure_membership_in_default_org(user)
      token = JsonWebToken.encode(user_id: user.id)

      render_success(
        {
          token: token,
          user: user_payload(user),
          organizations: organizations_payload(user)
        },
        "Google sign-in successful"
      )
    rescue => e
      Rails.logger.error "Google sign-in error: #{e.message}"
      render_error("Authentication failed", e.message, :unauthorized)
    end
  end

  def logout
    render_success(nil, "Logged out successfully")
  end

  def profile
    render_success(
      user_payload(current_user).merge(
        organization: organization_payload(current_organization),
        membership_role: current_membership&.role
      )
    )
  end

  private

  def user_payload(user)
    {
      id:    user.id,
      name:  user.name,
      email: user.email,
      role:  user.highest_role&.key || "associate",
      phone: user.phone_number
    }
  end

  def organizations_payload(user)
    user.organizations.order(:name).map { |org| organization_payload(org) }
  end

  def organization_payload(org)
    return nil unless org
    {
      id:             org.id,
      name:           org.name,
      subdomain:      org.subdomain,
      primary_color:  org.primary_color,
      accent_color:   org.accent_color,
      logo_url:       (org.logo.attached? ? Rails.application.routes.url_helpers.url_for(org.logo) : nil),
      role:           current_user&.membership_for(org)&.role
    }
  rescue
    { id: org.id, name: org.name, subdomain: org.subdomain, primary_color: org.primary_color, accent_color: org.accent_color, logo_url: nil }
  end

  # Mobile users created via OAuth need a default-org membership so the
  # back-compat "first org" fallback in BaseController has something to find.
  def ensure_membership_in_default_org(user)
    default_org = Organization.find_by(subdomain: "tecaudex")
    return unless default_org
    return if user.member_of?(default_org)

    role = user.admin? ? "owner" : "admin"
    user.memberships.create(organization: default_org, role: role)
  end

  def verify_google_token(id_token)
    require "net/http"
    require "json"

    uri = URI("https://oauth2.googleapis.com/tokeninfo?id_token=#{id_token}")
    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      payload = JSON.parse(response.body)

      valid_client_ids = FirebaseConfig.all_client_ids
      token_audience = payload["aud"]

      if FirebaseConfig.valid_client_id?(token_audience)
        Rails.logger.info "Google token verified for client: #{token_audience}"
        payload
      else
        Rails.logger.error "Token audience mismatch: expected one of #{valid_client_ids}, got #{token_audience}"
        nil
      end
    else
      Rails.logger.error "Google token verification failed: #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "Error verifying Google token: #{e.message}"
    nil
  end
end
