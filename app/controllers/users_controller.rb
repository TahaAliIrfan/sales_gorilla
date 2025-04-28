class UsersController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_user, only: [:show, :assign_role, :remove_role, :manage_associates, :assign_associate, :remove_associate]
  before_action :require_permission, except: [:show]
  before_action :require_admin_for_assignment, only: [:manage_associates, :assign_associate, :remove_associate]

  def index
    if current_user.admin?
      @users = User.all.order(:name)
    elsif current_user.manager?
      @users = current_user.associates.order(:name)
    else
      redirect_to root_path, alert: "You don't have permission to view this page."
    end
  end

  def show
    # Check if the current user has permission to view this user's details
    unless current_user.admin? || current_user == @user || 
           (current_user.manager? && current_user.associates.include?(@user))
      redirect_to root_path, alert: "You don't have permission to view this user's details."
      return
    end
    
    @role_assignments = @user.role_assignments.includes(:role, :assigned_by)
    @available_roles = Role.all
    
    # Get resources that current user can manage
    if current_user.admin?
      # Admin can assign any role to any resource
      @resources = User.where.not(id: @user.id).order(:name)
    elsif current_user.manager?
      # Manager can only assign roles to their associates
      @resources = current_user.associates.where.not(id: @user.id).order(:name)
    else
      @resources = []
    end
  end

  def associates
    if current_user.admin?
      @users = User.joins(:role_assignments)
                  .where(role_assignments: { role: Role.associate })
                  .distinct
                  .order(:name)
    elsif current_user.manager?
      @users = current_user.associates.order(:name)
    else
      redirect_to root_path, alert: "You don't have permission to view associates."
      return
    end
  end

  def managers
    if current_user.admin?
      @users = User.joins(:role_assignments)
                  .where(role_assignments: { role: Role.manager })
                  .distinct
                  .order(:name)
    else
      redirect_to root_path, alert: "You don't have permission to view managers."
      return
    end
  end

  def assign_role
    # This action is handled by RoleAssignmentsController#create
    redirect_to user_path(@user)
  end

  def remove_role
    # This action is handled by RoleAssignmentsController#destroy
    redirect_to user_path(@user)
  end

  # Shows the UI for managing a manager's associates
  def manage_associates
    # Verify that the user is a manager
    unless @user.manager?
      redirect_to user_path(@user), alert: "This user is not a manager."
      return
    end
    
    # Get the manager's current associates
    @current_associates = @user.associates.includes(:role_assignments)
    
    # Get all users with associate role who aren't already assigned to this manager
    # Make sure to preload role_assignments to avoid N+1 queries
    @available_associates = User.includes(:role_assignments, :roles)
                              .joins(:role_assignments)
                              .where(role_assignments: { role: Role.associate })
                              .where.not(id: @current_associates.pluck(:id))
                              .distinct
  end
  
  # Handles the assignment of associates to a manager
  def assign_associate
    # Verify that the user is a manager
    unless @user.manager?
      respond_to do |format|
        format.html { redirect_to user_path(@user), alert: "This user is not a manager." }
        format.json { render json: { success: false, message: "This user is not a manager." }, status: :unprocessable_entity }
      end
      return
    end
    
    # Get the associate ID from the params
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
  
  # Handles the removal of an associate from a manager
  def remove_associate
    associate_id = params[:associate_id]
    
    unless associate_id.present?
      redirect_to manage_associates_user_path(@user), alert: "No associate specified for removal."
      return
    end
    
    associate = User.find_by(id: associate_id)
    
    if associate && @user.remove_associate(associate, assigned_by: current_user)
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

  def require_permission
    unless current_user.admin? || current_user.manager?
      redirect_to root_path, alert: "You don't have permission to manage users."
    end
  end
  
  def require_admin_for_assignment
    unless current_user.admin?
      redirect_to root_path, alert: "Only administrators can manage associate assignments."
    end
  end
end
