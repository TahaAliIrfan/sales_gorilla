class RolesController < ApplicationController
  layout "tenant"
  before_action :require_login
  before_action :require_admin
  before_action :set_role, only: [:show, :edit, :update, :destroy]

  def index
    @roles = Role.all.order(hierarchy_level: :desc)
  end

  def show
    @users = @role.users.distinct
  end

  def new
    @role = Role.new
  end

  def create
    @role = Role.new(role_params)

    if @role.save
      redirect_to roles_path, notice: "Role was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @role.update(role_params)
      redirect_to roles_path, notice: "Role was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @role.destroy
      redirect_to roles_path, notice: "Role was successfully deleted."
    else
      redirect_to roles_path, alert: "Cannot delete this role as it is currently assigned to users."
    end
  end

  private

  def set_role
    @role = Role.find(params[:id])
  end

  def role_params
    params.require(:role).permit(:name, :key, :description, :hierarchy_level)
  end

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "You don't have permission to manage roles."
    end
  end
end
