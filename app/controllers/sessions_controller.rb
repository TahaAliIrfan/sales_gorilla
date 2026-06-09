class SessionsController < ApplicationController
  # Internal accounts auto-promoted to owner of the default org on sign-in.
  INTERNAL_ADMIN_EMAILS = %w[
    sarmad.mansoor@tecaudex.com taha.irfan@tecaudex.com arham.anwaar@tecaudex.com
  ].freeze

  # GET /auth/google_oauth2  →  kicks off OmniAuth (redirect handled there).
  # The /signin page itself is owned by Users::SessionsController now.
  def new
    redirect_to "/auth/google_oauth2"
  end

  # OAuth callback (Google). Email/password sign-in goes through Devise's
  # Users::SessionsController instead.
  def create
    auth = request.env["omniauth.auth"]

    # Resolve the user in three steps so Google sign-in links to an existing
    # account instead of creating a duplicate (which would collide on the
    # unique email index — e.g. when the user first signed up with a password):
    #   1. by Google identity (provider + uid)
    #   2. by email — link the Google identity onto that account
    #   3. otherwise create a fresh, already-confirmed Google account
    user = User.find_by(provider: auth.provider, uid: auth.uid)
    user ||= User.where("lower(email) = ?", auth.info.email.to_s.downcase).first

    if user
      user.update(provider: auth.provider, uid: auth.uid) if user.provider.blank? || user.uid.blank?
    else
      user = User.new(name: auth.info.name, email: auth.info.email,
                      provider: auth.provider, uid: auth.uid)
      user.skip_confirmation! # Google already verified the email; no confirmation needed
      user.save!
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
  # the default workspace automatically. New members default to least-privilege
  # "member"; internal admin emails are promoted to owner.
  def ensure_membership_in_default_org(user)
    default_org = Organization.find_by(subdomain: "tecaudex") || Organization.first
    return unless default_org
    internal_admin = INTERNAL_ADMIN_EMAILS.include?(user.email.to_s.downcase)

    unless user.member_of?(default_org)
      user.memberships.create(organization: default_org, role: internal_admin ? "owner" : "member")
    end
    user.grant_org_role!(default_org, "owner") if internal_admin && !user.owner?(default_org)
  end
end
