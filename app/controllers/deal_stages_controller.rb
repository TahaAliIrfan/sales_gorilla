class DealStagesController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_deal_stage, only: [:edit, :update, :destroy]
  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    @deal_stages = policy_scope(DealStage)
    @pipelines = policy_scope(Pipeline).includes(:deal_stages)
    authorize DealStage
  end

  def new
    @pipeline = Pipeline.find(params[:pipeline_id]) if params[:pipeline_id]
    @deal_stage = @pipeline ? @pipeline.deal_stages.build : DealStage.new
    authorize @deal_stage
    
    # Set next position for the pipeline
    if @pipeline
      @deal_stage.position = @pipeline.deal_stages.maximum(:position).to_i + 1
    end
  end

  def create
    if params[:pipeline_id]
      @pipeline = Pipeline.find(params[:pipeline_id])
      @deal_stage = @pipeline.deal_stages.build(deal_stage_params)
    else
      @deal_stage = DealStage.new(deal_stage_params)
    end
    
    authorize @deal_stage

    if @deal_stage.save
      redirect_path = @pipeline || deal_stages_path
      redirect_to redirect_path, notice: 'Deal stage was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @deal_stage
  end

  def update
    authorize @deal_stage
    if @deal_stage.update(deal_stage_params)
      redirect_to @deal_stage.pipeline, notice: 'Deal stage was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @deal_stage
    pipeline = @deal_stage.pipeline
    
    if @deal_stage.deals.any?
      redirect_to pipeline, alert: 'Cannot delete a stage that has deals assigned to it.'
    else
      @deal_stage.destroy
      redirect_to pipeline, notice: 'Deal stage was successfully deleted.'
    end
  end

  private

  def set_deal_stage
    @deal_stage = DealStage.find(params[:id])
  end

  def deal_stage_params
    params.require(:deal_stage).permit(:name, :position, :description, :active, :pipeline_id)
  end
  
  def require_login
    unless session[:user_id]
      flash[:error] = "You must be logged in to access this section"
      redirect_to root_path
    end
  end
  
  def require_admin
    unless current_user&.admin?
      flash[:error] = "You must be an admin to access this section"
      redirect_to dashboard_path
    end
  end
  
  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
end
