class TasksController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_task, only: [:show, :edit, :update, :destroy, :complete]
  before_action :authorize_admin_for_all_tasks, only: [:index]
  before_action :authorize_task_access, only: [:show, :edit, :update, :destroy, :complete]
  before_action :ensure_user_assignment_for_non_admin, only: [:create, :update]
  before_action :process_due_date, only: [:create, :update]

  def index
    @tasks = Task.includes(:user, :customer).order(due_date: :asc)
    
    if params[:status].present?
      @tasks = @tasks.where(status: params[:status])
    end
    
    if params[:user_id].present?
      @tasks = @tasks.where(user_id: params[:user_id])
    end
    
    if params[:priority].present?
      @tasks = @tasks.where(priority: params[:priority])
    end
    
    if params[:due_date].present?
      date = Date.parse(params[:due_date])
      @tasks = @tasks.where('due_date >= ? AND due_date <= ?', date.beginning_of_day, date.end_of_day)
    end
  end
  
  def my_tasks
    @tasks = current_user.tasks.includes(:customer).order(due_date: :asc)
    
    if params[:status].present?
      @tasks = @tasks.where(status: params[:status])
    end
    
    if params[:priority].present?
      @tasks = @tasks.where(priority: params[:priority])
    end
    
    if params[:due_date].present?
      date = Date.parse(params[:due_date])
      @tasks = @tasks.where('due_date >= ? AND due_date <= ?', date.beginning_of_day, date.end_of_day)
    end
    
    render :index
  end

  def show
  end

  def new
    @task = Task.new
    @task.user_id = current_user.id
    @task.due_date = Date.today + 1.day
    @task.status = :pending
    @task.priority = 'Medium'
    
    if params[:customer_id].present?
      @task.customer_id = params[:customer_id]
    end
  end

  def edit
  end

  def create
    @task = Task.new(task_params)
    
    respond_to do |format|
      if @task.save
        format.html { redirect_to task_path(@task), notice: 'Task was successfully created.' }
        format.json { render :show, status: :created, location: @task }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @task.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @task.update(task_params)
        format.html { redirect_to task_path(@task), notice: 'Task was successfully updated.' }
        format.json { render :show, status: :ok, location: @task }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @task.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @task.destroy
    respond_to do |format|
      format.html { redirect_to tasks_path, notice: 'Task was successfully deleted.' }
      format.json { head :no_content }
    end
  end
  
  def complete
    @task.complete!
    
    # Check if the request is coming from the dashboard
    if params[:return_to] == 'dashboard'
      if current_user.admin?
        redirect_to admin_dashboard_path, notice: 'Task marked as completed.'
      else
        redirect_to dashboard_path, notice: 'Task marked as completed.'
      end
    else
      redirect_to task_path(@task), notice: 'Task marked as completed.'
    end
  end

  private
    def set_task
      @task = Task.find(params[:id])
    end

    def task_params
      permitted_params = params.require(:task).permit(:title, :description, :due_date, :status, :user_id, :customer_id, :priority)
      # If user is not admin, ensure they can only assign to themselves
      permitted_params[:user_id] = current_user.id unless current_user.admin?
      permitted_params
    end
    
    def process_due_date
      return unless params[:task] && params[:task][:due_date].present?
      
      # If the due_date is just a date (no time component), set it to end of day
      if params[:task][:due_date].match?(/^\d{4}-\d{2}-\d{2}$/)
        date = Date.parse(params[:task][:due_date])
        params[:task][:due_date] = date.end_of_day
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
    
    def authorize_admin_for_all_tasks
      redirect_to my_tasks_tasks_path unless current_user.admin?
    end
    
    def authorize_task_access
      unless current_user.admin? || @task.user_id == current_user.id
        redirect_to my_tasks_tasks_path, alert: "You don't have permission to access this task."
      end
    end
    
    def ensure_user_assignment_for_non_admin
      return if current_user.admin?
      
      # For create action, ensure the task is assigned to the current user
      if action_name == 'create'
        params[:task][:user_id] = current_user.id
      # For update action, don't allow changing the user_id
      elsif action_name == 'update'
        params[:task][:user_id] = @task.user_id
      end
    end
end
