class TasksController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_task, only: [:show, :edit, :update, :destroy, :complete]
  before_action :authorize_admin_for_all_tasks, only: [:index]
  before_action :authorize_task_access, only: [:show, :edit, :update, :destroy, :complete]

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
    @task.due_date = Time.current + 1.day
    
    if params[:customer_id].present?
      @task.customer_id = params[:customer_id]
    end
  end

  def edit
  end

  def create
    @task = Task.new(task_params)
    
    # Only admins can assign tasks to other users
    unless current_user.admin?
      @task.user_id = current_user.id
    end

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
      # Only admins can change the assigned user
      unless current_user.admin?
        params[:task][:user_id] = @task.user_id
      end
      
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
    redirect_to task_path(@task), notice: 'Task marked as completed.'
  end

  private
    def set_task
      @task = Task.find(params[:id])
    end

    def task_params
      params.require(:task).permit(:title, :description, :due_date, :status, :user_id, :customer_id, :priority)
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
end
