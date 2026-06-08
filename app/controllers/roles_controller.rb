class RolesController < ApplicationController
  layout "relay"
  before_action :require_login
  before_action :require_roles_manager
  before_action :set_role, only: %i[show edit update destroy]

  # All roles in the current organization, highest authority first.
  def index
    @roles = current_organization.roles.order(hierarchy_level: :desc)
  end

  def show
    @members = current_organization.users
                                   .where(memberships: { role_id: @role.id })
                                   .order(:name)
  end

  def new
    @role = current_organization.roles.new(hierarchy_level: 20)
  end

  def create
    @role = current_organization.roles.new(role_params)
    @role.system = false

    if @role.save
      redirect_to role_path(@role), notice: "Role “#{@role.name}” created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @role.update(permitted_role_params)
      redirect_to role_path(@role), notice: "Role “#{@role.name}” updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @role.system?
      redirect_to roles_path, alert: "System roles can't be deleted."
    elsif @role.memberships.exists?
      redirect_to roles_path, alert: "Reassign this role's members before deleting it."
    else
      @role.destroy
      redirect_to roles_path, notice: "Role deleted."
    end
  end

  private

  def set_role
    @role = current_organization.roles.find(params[:id])
  end

  def role_params
    params.require(:role)
          .permit(:name, :key, :description, :hierarchy_level, permissions: [])
          .tap { |p| p[:permissions] = Array(p[:permissions]).reject(&:blank?) if p.key?(:permissions) }
  end

  # System roles have fixed identity/rank — only their description and granted
  # permissions are editable. Custom roles are fully editable.
  def permitted_role_params
    return role_params unless @role.system?
    role_params.slice(:description, :permissions)
  end

  def require_roles_manager
    unless pundit_user.can?("roles.manage")
      redirect_to root_path, alert: "You don't have permission to manage roles."
    end
  end
end
