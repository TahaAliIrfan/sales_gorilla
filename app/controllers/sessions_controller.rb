class SessionsController < ApplicationController
  def new
    redirect_to "/auth/google_oauth2"
  end

  def create
    auth = request.env["omniauth.auth"]
    user = User.find_or_create_by(provider: auth.provider, uid: auth.uid) do |u|
      u.name = auth.info.name
      u.email = auth.info.email
    end

    # Assign admin role to specific users if not already assigned
    admin_emails = [ "sarmad.mansoor@tecaudex.com", "taha.irfan@tecaudex.com", "arham.anwaar@tecaudex.com" ]
    if admin_emails.include?(user.email.downcase) && !user.admin?
      user.make_admin!
    end

    # Save Google OAuth tokens if they exist
    if auth.credentials.present?
      user.update(
        google_token: auth.credentials.token,
        google_refresh_token: auth.credentials.refresh_token || user.google_refresh_token,
        google_token_expires_at: auth.credentials.expires_at.present? ? Time.at(auth.credentials.expires_at) : nil
      )
    end

    # Allow specific email addresses or @tecaudex.com domain
    allowed_emails = [ "ifrah.khurram97@gmail.com", "tahairfan1993@gmail.com" ]

    if user.email.ends_with?("@tecaudex.com") || allowed_emails.include?(user.email.downcase)
      session[:user_id] = user.id
      session[:user_email] = user.email
      ensure_membership_in_default_org(user)
      flash[:success] = "Successfully signed in!"
      redirect_to organizations_path
    else
      flash[:error] = "Access restricted to authorized email addresses"
      redirect_to root_path
    end
  rescue => e
    flash[:error] = "Authentication error: #{e.message}"
    redirect_to root_path
  end

  def destroy
    session[:user_id] = nil
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
  # the existing Tecaudex workspace automatically.
  def ensure_membership_in_default_org(user)
    default_org = Organization.find_by(subdomain: "tecaudex")
    return unless default_org
    return if user.member_of?(default_org)

    role = user.admin? ? "owner" : "admin"
    user.memberships.create(organization: default_org, role: role)
  end
end
