class UsersController < ApplicationController
  layout "relay"
  before_action :require_login
  before_action :require_admin
  before_action :set_user, only: [ :show, :update_role, :toggle_active, :resend_invite, :manage_associates, :assign_associate, :remove_associate ]

  # Org members and the roles assignable within the current organization.
  def index
    @users = org_users.order(:name)
    @roles = assignable_roles
  end

  def show
    @membership = @user.membership_for(current_organization)
    @manager    = @membership&.reports_to&.user
    @reports    = @user.associates
  end

  # Set a member's capability role within the current organization.
  def update_role
    role_key = params[:role_key].to_s
    role     = current_organization.roles.find_by(key: role_key)

    unless role
      return render json: { success: false, message: "Invalid role" }, status: :unprocessable_entity
    end
    unless current_user.can_assign_role?(role_key)
      return render json: { success: false, message: "You can't assign the #{role_key} role." }, status: :forbidden
    end

    if @user.grant_org_role!(current_organization, role_key)
      render json: { success: true, message: "Role updated to #{role.name}." }
    else
      render json: { success: false, message: "Failed to assign role" }, status: :unprocessable_entity
    end
  end

  def toggle_active
    if @user.active?
      @user.deactivate!
      render json: { success: true, message: "User deactivated.", active: false }
    else
      @user.activate!
      render json: { success: true, message: "User activated.", active: true }
    end
  end

  # Invite (or add) a person to the current organization by email.
  #   - Unknown email  -> create a confirmed, password-less User and email a
  #     set-password invitation (Devise recoverable token).
  #   - Known email    -> just add a Membership and email a "you've been added"
  #     notice (users are global; one account spans many orgs).
  def invite
    email    = params[:email].to_s.strip.downcase
    role_key = params[:role_key].to_s.presence || "member"
    back     = settings_path(tab: "team")

    unless pundit_user.can?("users.invite")
      return redirect_to back, alert: "You don't have permission to invite users."
    end
    unless current_user.can_assign_role?(role_key)
      return redirect_to back, alert: "You can't assign the #{role_key} role."
    end
    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      return redirect_to back, alert: "Please enter a valid email address."
    end

    existing  = User.find_by("lower(email) = ?", email)
    new_user  = existing.nil?

    if existing&.member_of?(current_organization)
      return redirect_to back, alert: "#{email} is already a member of this organization."
    end

    user = nil
    User.transaction do
      if new_user
        user = User.new(email: email, name: email.split("@").first.tr(".", " ").humanize,
                        password: SecureRandom.base58(24))
        user.skip_confirmation! # the invitation email itself proves email ownership
        user.save!
      else
        user = existing
      end
      user.grant_org_role!(current_organization, role_key)
    end

    if new_user
      raw_token = user.send(:set_reset_password_token)
      UserMailer.organization_invitation(user, current_organization, current_user, raw_token).deliver_later
    else
      UserMailer.organization_added(user, current_organization, current_user).deliver_later
    end

    redirect_to back, notice: "Invitation sent to #{email}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to back, alert: "Could not invite #{email}: #{e.record.errors.full_messages.to_sentence}"
  end

  # Re-send the set-password invitation to a member who hasn't accepted yet
  # (never signed in). Generates a fresh reset-password token each time.
  def resend_invite
    back = settings_path(tab: "team")
    unless pundit_user.can?("users.invite")
      return redirect_to back, alert: "You don't have permission to invite users."
    end
    if @user.sign_in_count.to_i.positive?
      return redirect_to back, alert: "#{@user.email} has already accepted their invitation."
    end

    raw_token = @user.send(:set_reset_password_token)
    UserMailer.organization_invitation(@user, current_organization, current_user, raw_token).deliver_later
    redirect_to back, notice: "Invitation re-sent to #{@user.email}."
  end

  # Members with the "member" role in the current org.
  def associates
    @users = org_users.where(memberships: { role_id: role_id_for("member") }).order(:name)
  end

  # Members with the "manager" role in the current org.
  def managers
    @users = org_users.where(memberships: { role_id: role_id_for("manager") }).order(:name)
  end

  def manage_associates
    unless @user.manager?
      redirect_to user_path(@user), alert: "This user is not a manager."
      return
    end

    @current_associates   = @user.associates.order(:name)
    @available_associates = org_users
                              .where(memberships: { role_id: role_id_for("member") })
                              .where.not(id: @current_associates.select(:id))
                              .order(:name)
  end

  def assign_associate
    associate = User.find_by(id: params[:associate_id])

    if associate && @user.assign_associate(associate)
      respond_to do |format|
        format.html { redirect_to manage_associates_user_path(@user), notice: "Assigned #{associate.name} to #{@user.name}." }
        format.json { render json: { success: true, message: "Associate assigned." } }
      end
    else
      respond_to do |format|
        format.html { redirect_to manage_associates_user_path(@user), alert: "Failed to assign associate." }
        format.json { render json: { success: false, message: "Failed to assign associate." }, status: :unprocessable_entity }
      end
    end
  end

  def remove_associate
    associate = User.find_by(id: params[:associate_id])

    if associate && @user.remove_associate(associate)
      respond_to do |format|
        format.html { redirect_to manage_associates_user_path(@user), notice: "Removed #{associate.name} from #{@user.name}'s team." }
        format.json { render json: { success: true, message: "Associate removed." } }
      end
    else
      respond_to do |format|
        format.html { redirect_to manage_associates_user_path(@user), alert: "Failed to remove associate." }
        format.json { render json: { success: false, message: "Failed to remove associate." }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_user
    @user = org_users.find(params[:id])
  end

  # Users scoped to members of the current organization.
  def org_users
    current_organization.users.joins(:memberships)
                        .where(memberships: { organization_id: current_organization.id })
  end

  def role_id_for(key)
    current_organization.roles.system_roles.find_by(key: key)&.id
  end

  # Roles this admin may hand out (system + custom), highest-authority first.
  def assignable_roles
    current_organization.roles
                        .order(hierarchy_level: :desc)
                        .map { |r| { key: r.key, name: r.name } }
                        .select { |r| current_user.can_assign_role?(r[:key]) }
  end

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "Access denied. Only administrators can manage users."
    end
  end
end
