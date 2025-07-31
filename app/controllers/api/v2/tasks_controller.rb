class Api::V2::TasksController < Api::V2::BaseController
  before_action :set_task, only: [:show, :update, :destroy, :mark_as_completed, :mark_as_pending]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @tasks = policy_scope(Task)
    
    # Apply filters
    @tasks = @tasks.where(user_id: params[:user_id]) if params[:user_id].present?
    @tasks = @tasks.where(customer_id: params[:customer_id]) if params[:customer_id].present?
    @tasks = @tasks.where(status: params[:status]) if params[:status].present?
    @tasks = @tasks.where(priority: params[:priority]) if params[:priority].present?
    
    # Date filters
    if params[:due_date_from].present?
      @tasks = @tasks.where('due_date >= ?', Date.parse(params[:due_date_from]))
    end
    
    if params[:due_date_to].present?
      @tasks = @tasks.where('due_date <= ?', Date.parse(params[:due_date_to]))
    end
    
    # Search
    @tasks = @tasks.where('title ILIKE ? OR description ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    
    # Sorting
    sort_field = params[:sort] || 'due_date'
    sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
    @tasks = @tasks.order("#{sort_field} #{sort_direction}")
    
    # Pagination
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    @tasks = @tasks.page(page).per(per_page)
    
    render_success({
      tasks: @tasks.as_json(
        include: {
          user: { only: [:id, :name] },
          customer: { only: [:id, :name, :company] }
        }
      ),
      pagination: {
        current_page: @tasks.current_page,
        total_pages: @tasks.total_pages,
        total_count: @tasks.total_count,
        per_page: @tasks.limit_value
      }
    })
  end

  def show
    authorize @task
    render_success({
      task: @task.as_json(
        include: {
          user: { only: [:id, :name] },
          customer: { only: [:id, :name, :company, :email, :phone] }
        }
      )
    })
  end

  def create
    @task = Task.new(task_params)
    @task.user_id ||= current_user.id
    
    authorize @task
    
    if @task.save
      render_success(
        { 
          task: @task.as_json(
            include: {
              user: { only: [:id, :name] },
              customer: { only: [:id, :name, :company] }
            }
          )
        }, 
        'Task created successfully', 
        :created
      )
    else
      render_error('Failed to create task', @task.errors.full_messages, :unprocessable_entity)
    end
  end

  def update
    authorize @task
    
    if @task.update(task_params)
      render_success(
        { 
          task: @task.as_json(
            include: {
              user: { only: [:id, :name] },
              customer: { only: [:id, :name, :company] }
            }
          )
        }, 
        'Task updated successfully'
      )
    else
      render_error('Failed to update task', @task.errors.full_messages, :unprocessable_entity)
    end
  end

  def destroy
    authorize @task
    
    if @task.destroy
      render_success(nil, 'Task deleted successfully')
    else
      render_error('Failed to delete task')
    end
  end

  def mark_as_completed
    authorize @task
    
    if @task.update(status: 'completed', completed_at: Time.current)
      render_success({ task: @task }, 'Task marked as completed')
    else
      render_error('Failed to mark task as completed', @task.errors.full_messages, :unprocessable_entity)
    end
  end

  def mark_as_pending
    authorize @task
    
    if @task.update(status: 'pending', completed_at: nil)
      render_success({ task: @task }, 'Task marked as pending')
    else
      render_error('Failed to mark task as pending', @task.errors.full_messages, :unprocessable_entity)
    end
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :due_date, :priority, :status, :customer_id, :user_id)
  end
end