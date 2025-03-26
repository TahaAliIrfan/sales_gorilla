class TasksController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_task, only: [:show, :edit, :update, :destroy, :complete]
  after_action :verify_authorized, except: [:index, :my_tasks]
  after_action :verify_policy_scoped, only: [:index, :my_tasks]

  def index
    authorize Task
    @tasks = policy_scope(Task).includes(:user, :customer).order(due_date: :asc)
    
    # Default to pending tasks if no status is specified
    if params[:status].present?
      @tasks = @tasks.where(status: params[:status])
    else
      @tasks = @tasks.pending
      params[:status] = 'pending'
    end
    
    if params[:user_id].present?
      @tasks = @tasks.where(user_id: params[:user_id])
    end
    
    if params[:priority].present?
      @tasks = @tasks.where(priority: params[:priority])
    end
    
    if params[:due_date].present?
      case params[:due_date]
      when 'today'
        @tasks = @tasks.for_today
      when 'upcoming'
        @tasks = @tasks.upcoming
      when 'overdue'
        @tasks = @tasks.overdue
      end
    end
  end

  def my_tasks
    @tasks = policy_scope(Task).includes(:customer).order(due_date: :asc)
    
    # Default behavior: show all tasks for today (including completed and cancelled)
    if params[:status].present?
      # If status is explicitly specified, filter by that status
      @tasks = @tasks.where(status: params[:status])
    elsif params[:due_date].present?
      # If due date is specified, filter by that date range
      case params[:due_date]
      when 'today'
        @tasks = @tasks.for_today
      when 'upcoming'
        @tasks = @tasks.upcoming 
      when 'overdue'
        @tasks = @tasks.overdue
      end
    else
      # Default: Show today's tasks including completed and cancelled
      @tasks = @tasks.for_today
      params[:due_date] = 'today'
    end
    
    if params[:priority].present?
      @tasks = @tasks.where(priority: params[:priority])
    end
    
    render :index
  end

  def new
    @task = Task.new
    authorize @task
    
    if params[:customer_id].present?
      @task.customer_id = params[:customer_id]
    end
    
    if params[:deal_id].present?
      @task.description = "Related to Deal ID: #{params[:deal_id]}"
    end
    
    @customers = current_user.admin? ? Customer.all : Customer.where(user_id: current_user.id)
    @users = current_user.admin? ? User.all : [current_user]
  end

  def create
    @task = Task.new(task_params)
    authorize @task
    
    # Ensure task is assigned to current user if not admin
    if !current_user.admin? && @task.user_id != current_user.id
      @task.user_id = current_user.id
    end

    respond_to do |format|
      if @task.save
        format.html { redirect_to @task, notice: 'Task was successfully created.' }
        format.json { render :show, status: :created, location: @task }
      else
        @customers = current_user.admin? ? Customer.all : Customer.where(user_id: current_user.id)
        @users = current_user.admin? ? User.all : [current_user]
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @task.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    authorize @task
    @customers = current_user.admin? ? Customer.all : Customer.where(user_id: current_user.id)
    @users = current_user.admin? ? User.all : [current_user]
  end

  def show
    authorize @task
  end

  def update
    authorize @task
    
    # Ensure task is assigned to current user if not admin
    update_params = task_params
    if !current_user.admin? && update_params[:user_id].to_i != current_user.id
      update_params = update_params.merge(user_id: current_user.id)
    end
    
    respond_to do |format|
      if @task.update(update_params)
        format.html { redirect_to @task, notice: 'Task was successfully updated.' }
        format.json { render :show, status: :ok, location: @task }
      else
        @customers = current_user.admin? ? Customer.all : Customer.where(user_id: current_user.id)
        @users = current_user.admin? ? User.all : [current_user]
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @task.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    authorize @task
    @task.destroy
    respond_to do |format|
      format.html { redirect_to tasks_url, notice: 'Task was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def complete
    authorize @task
    @task.complete!
    respond_to do |format|
      format.html { 
        if params[:return_to] == 'dashboard'
          redirect_to dashboard_path, notice: 'Task marked as complete.'
        elsif params[:return_to] == 'my_tasks_dashboard' || params[:return_to] == 'my_tasks'
          redirect_to my_tasks_tasks_path(due_date: 'today'), notice: 'Task marked as complete.'
        elsif params[:return_to] == 'current_page'
          # Get the query parameters from the original request
          redirect_params = params.permit!.except(:controller, :action, :id, :return_to)
          
          # Determine which path to redirect to based on the original action
          redirect_path = if request.referer&.include?('my_tasks')
            my_tasks_tasks_path(redirect_params)
          else
            tasks_path(redirect_params)
          end
          
          redirect_to redirect_path, notice: 'Task marked as complete.'
        else
          redirect_to request.referer || tasks_url, notice: 'Task marked as complete.' 
        end
      }
      format.json { head :no_content }
    end
  end

  private
    def set_task
      @task = Task.find(params[:id])
    end

    def task_params
      permitted_params = params.require(:task).permit(:title, :description, :due_date, :status, :user_id, :customer_id, :priority)
      
      # Only allow user assignment if the current user is an admin
      unless current_user.admin?
        permitted_params = permitted_params.except(:user_id)
      end
      
      permitted_params
    end
    
    def process_due_date
      return unless params[:task] && params[:task][:due_date].present?
      
      due_date = params[:task][:due_date]
      unless due_date.is_a?(Date) || due_date.is_a?(Time) || due_date.is_a?(DateTime)
        begin
          parsed_date = Date.parse(due_date.to_s)
          params[:task][:due_date] = parsed_date
        rescue ArgumentError => e
          logger.error "Failed to parse due date: #{e.message}"
        end
      end
    end
    
    def require_login
      unless session[:user_id]
        redirect_to signin_path, alert: "Please sign in to access this page."
      end
    end
    
    def current_user
      @current_user ||= User.find_by(id: session[:user_id])
    end
end
