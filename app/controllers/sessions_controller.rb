class SessionsController < ApplicationController
  # GET /auth/google_oauth2  →  kicks off OmniAuth (redirect handled there).
  # The /signin page itself is owned by Users::SessionsController now.
  def new
    redirect_to "/auth/google_oauth2"
  end

  # OAuth callback (Google). Email/password sign-in goes through Devise's
  # Users::SessionsController instead.
  def create
    auth = request.env["omniauth.auth"]
    user = User.find_or_create_by(provider: auth.provider, uid: auth.uid) do |u|
      u.name  = auth.info.name
      u.email = auth.info.email
    end

    # Auto-promote known internal accounts.
    admin_emails = [ "sarmad.mansoor@tecaudex.com", "taha.irfan@tecaudex.com", "arham.anwaar@tecaudex.com" ]
    if admin_emails.include?(user.email.to_s.downcase) && !user.admin?
      user.make_admin!
    end

    if auth.credentials.present?
      user.update(
        google_token:            auth.credentials.token,
        google_refresh_token:    auth.credentials.refresh_token || user.google_refresh_token,
        google_token_expires_at: auth.credentials.expires_at.present? ? Time.at(auth.credentials.expires_at) : nil
      )
    end

    session[:user_id]    = user.id
    session[:user_email] = user.email
    sign_in(user) if user.persisted?  # Warden session so Devise helpers also work
    ensure_membership_in_default_org(user)
    flash[:success] = "Successfully signed in!"
    redirect_to organizations_path
  rescue => e
    flash[:error] = "Authentication error: #{e.message}"
    redirect_to root_path
  end

  def destroy
    sign_out(:user) if respond_to?(:sign_out)  # clear Warden if Devise was used
    session[:user_id]    = nil
    session[:user_email] = nil
    flash[:success] = "Signed out successfully"
    redirect_to root_path
  end

  def failure
    flash[:error] = "Authentication failed: #{params[:message]}"
    redirect_to root_path
  end

  private

  # New users created via OAuth need a default-org membership so they land in
  # the default workspace automatically.
  def ensure_membership_in_default_org(user)
    default_org = Organization.find_by(subdomain: "tecaudex") || Organization.first
    return unless default_org
    return if user.member_of?(default_org)

    role = user.admin? ? "owner" : "admin"
    user.memberships.create(organization: default_org, role: role)
  end
end
