class PipelinesController < ApplicationController
  layout "tenant"
  before_action :require_login
  before_action :set_pipeline, only: [:show, :edit, :update, :destroy, :assign_users]
  after_action :verify_authorized

  def index
    authorize Pipeline
    @pipelines = policy_scope(Pipeline).includes(:deal_stages, :users)
  end

  def show
    authorize @pipeline
    @deal_stages = @pipeline.deal_stages.ordered
    @assigned_users = @pipeline.users
    @deals_count = @pipeline.deals_count
  end

  def new
    @pipeline = Pipeline.new
    authorize @pipeline
  end

  def create
    @pipeline = Pipeline.new(pipeline_params)
    authorize @pipeline

    if @pipeline.save
      redirect_to @pipeline, notice: 'Pipeline was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @pipeline
  end

  def update
    authorize @pipeline

    if @pipeline.update(pipeline_params)
      redirect_to @pipeline, notice: 'Pipeline was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @pipeline
    
    if @pipeline.deals.exists?
      redirect_to pipelines_path, alert: 'Cannot delete pipeline with existing deals.'
    else
      @pipeline.destroy
      redirect_to pipelines_path, notice: 'Pipeline was successfully deleted.'
    end
  end

  def assign_users
    authorize @pipeline
    
    if params[:user_ids].present?
      # Clear existing assignments
      @pipeline.user_pipeline_assignments.destroy_all
      
      # Create new assignments
      params[:user_ids].each do |user_id|
        @pipeline.user_pipeline_assignments.create(user_id: user_id)
      end
      
      redirect_to @pipeline, notice: 'Users assigned successfully.'
    else
      redirect_to @pipeline, alert: 'Please select at least one user.'
    end
  end

  private

  def set_pipeline
    @pipeline = Pipeline.find(params[:id])
  end

  def pipeline_params
    params.require(:pipeline).permit(:name, :description, :active)
  end
  
  def require_login
    unless session[:user_id]
      flash[:error] = "You must be logged in to access this section"
      redirect_to root_path
    end
  end
  
  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
end