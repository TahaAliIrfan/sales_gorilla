class UsersController < ApplicationController
  layout "tenant"
  before_action :require_login
  before_action :require_admin
  before_action :set_user, only: [ :show, :update_role, :toggle_active ]

  # Hardcoded roles
  ROLES = [
    { key: "admin", name: "Administrator", level: 100, description: "Full access to the system" },
    { key: "manager", name: "Manager", level: 50, description: "Can manage team and view team data" },
    { key: "associate", name: "Associate", level: 10, description: "Basic user access" }
  ].freeze

  def index
    @users = User.all.order(:name)
    @roles = ROLES
  end

  def show
    # Only admins can view user details
    unless current_user.admin?
      redirect_to root_path, alert: "You don't have permission to access user management."
      return
    end

    @role_assignments = @user.role_assignments.includes(:role, :assigned_by)
  end

  def update_role
    role_key = params[:role_key]

    unless [ "admin", "manager", "associate" ].include?(role_key)
      render json: { success: false, message: "Invalid role" }, status: :unprocessable_entity
      return
    end

    # Remove all existing roles
    @user.role_assignments.destroy_all

    # Assign the new role
    role = Role.find_by(key: role_key)
    if role && @user.assign_role(role, assigned_by: current_user)
      render json: { success: true, message: "Role updated successfully to #{role.name}" }
    else
      render json: { success: false, message: "Failed to assign role" }, status: :unprocessable_entity
    end
  end

  def toggle_active
    if @user.active?
      if @user.deactivate!
        render json: { success: true, message: "User deactivated successfully", active: false }
      else
        render json: { success: false, message: "Failed to deactivate user" }, status: :unprocessable_entity
      end
    else
      if @user.activate!
        render json: { success: true, message: "User activated successfully", active: true }
      else
        render json: { success: false, message: "Failed to activate user" }, status: :unprocessable_entity
      end
    end
  end

  def associates
    @users = User.joins(:role_assignments)
                .where(role_assignments: { role: Role.associate })
                .distinct
                .order(:name)
  end

  def managers
    @users = User.joins(:role_assignments)
                .where(role_assignments: { role: Role.manager })
                .distinct
                .order(:name)
  end

  def manage_associates
    @user = User.find(params[:id])

    # Verify that the user is a manager
    unless @user.manager?
      redirect_to user_path(@user), alert: "This user is not a manager."
      return
    end

    # Get the manager's current associates
    @current_associates = @user.associates.includes(:role_assignments)

    # Get all users with associate role who aren't already assigned to this manager
    @available_associates = User.includes(:role_assignments, :roles)
                              .joins(:role_assignments)
                              .where(role_assignments: { role: Role.associate })
                              .where.not(id: @current_associates.pluck(:id))
                              .distinct
  end

  def assign_associate
    @user = User.find(params[:id])

    # Verify that the user is a manager
    unless @user.manager?
      respond_to do |format|
        format.html { redirect_to user_path(@user), alert: "This user is not a manager." }
        format.json { render json: { success: false, message: "This user is not a manager." }, status: :unprocessable_entity }
      end
      return
    end

    associate_id = params[:associate_id]

    if associate_id.blank?
      respond_to do |format|
        format.html { redirect_to manage_associates_user_path(@user), alert: "No associate specified for assignment." }
        format.json { render json: { success: false, message: "No associate specified for assignment." }, status: :unprocessable_entity }
      end
      return
    end

    associate = User.find_by(id: associate_id)

    if associate && @user.assign_associate(associate, assigned_by: current_user)
      respond_to do |format|
        format.html { redirect_to manage_associates_user_path(@user), notice: "Successfully assigned #{associate.name} to #{@user.name}." }
        format.json { render json: { success: true, message: "Successfully assigned associate." } }
      end
    else
      respond_to do |format|
        format.html { redirect_to manage_associates_user_path(@user), alert: "Failed to assign associate." }
        format.json { render json: { success: false, message: "Failed to assign associate." }, status: :unprocessable_entity }
      end
    end
  end

  def remove_associate
    @user = User.find(params[:id])
    associate_id = params[:associate_id]

    unless associate_id.present?
      redirect_to manage_associates_user_path(@user), alert: "No associate specified for removal."
      return
    end

    associate = User.find_by(id: associate_id)

    if associate && @user.remove_associate(associate)
      respond_to do |format|
        format.html { redirect_to manage_associates_user_path(@user), notice: "Successfully removed #{associate.name} from #{@user.name}'s associates." }
        format.json { render json: { success: true, message: "Successfully removed associate." } }
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
    @user = User.find(params[:id])
  end

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "Access denied. Only administrators can access user management."
    end
  end
end
