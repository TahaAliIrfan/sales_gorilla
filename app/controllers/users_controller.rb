class UsersController < ApplicationController
  layout "relay"
  before_action :require_login
  before_action :require_admin
  before_action :set_user, only: [ :show, :update_role, :toggle_active, :manage_associates, :assign_associate, :remove_associate ]

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
