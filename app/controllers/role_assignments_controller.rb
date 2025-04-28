class RoleAssignmentsController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :require_permission

  def create
    @user = User.find(params[:user_id])
    @role = Role.find(params[:role_id])
    
    # Check if current user can assign this role
    unless current_user.can_assign_role?(@role)
      redirect_to user_path(@user), alert: "You don't have permission to assign this role."
      return
    end
    
    # Get resource if present
    resource = find_resource if params[:resource_type].present? && params[:resource_id].present?
    
    # Create role assignment
    result = @user.assign_role(@role, assigned_by: current_user, resource: resource)
    
    if result
      redirect_to user_path(@user), notice: "Role successfully assigned."
    else
      redirect_to user_path(@user), alert: "Failed to assign role."
    end
  end

  def destroy
    @assignment = RoleAssignment.find(params[:id])
    @user = @assignment.user
    
    # Check if current user can manage this role
    unless current_user.admin? || @assignment.assigned_by == current_user
      redirect_to user_path(@user), alert: "You don't have permission to remove this role."
      return
    end
    
    if @assignment.destroy
      redirect_to user_path(@user), notice: "Role assignment removed successfully."
    else
      redirect_to user_path(@user), alert: "Failed to remove role assignment."
    end
  end

  private

  def require_permission
    unless current_user.admin? || current_user.manager?
      redirect_to root_path, alert: "You don't have permission to manage role assignments."
    end
  end
  
  def find_resource
    resource_type = params[:resource_type]
    resource_id = params[:resource_id]
    
    case resource_type
    when 'User'
      User.find_by(id: resource_id)
    # Add more resource types as needed
    else
      nil
    end
  end
end
