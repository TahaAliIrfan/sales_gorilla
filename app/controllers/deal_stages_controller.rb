class DealStagesController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_deal_stage, only: [:edit, :update, :destroy]
  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    @deal_stages = policy_scope(DealStage)
  end

  def new
    @deal_stage = DealStage.new
    authorize @deal_stage
  end

  def create
    @deal_stage = DealStage.new(deal_stage_params)
    authorize @deal_stage

    if @deal_stage.save
      redirect_to deal_stages_path, notice: 'Deal stage was successfully created.'
    else
      render :new
    end
  end

  def edit
    authorize @deal_stage
  end

  def update
    authorize @deal_stage
    if @deal_stage.update(deal_stage_params)
      redirect_to deal_stages_path, notice: 'Deal stage was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    authorize @deal_stage
    if @deal_stage.deals.any?
      redirect_to deal_stages_path, alert: 'Cannot delete a stage that has deals assigned to it.'
    else
      @deal_stage.destroy
      redirect_to deal_stages_path, notice: 'Deal stage was successfully deleted.'
    end
  end

  private

  def set_deal_stage
    @deal_stage = DealStage.find(params[:id])
  end

  def deal_stage_params
    params.require(:deal_stage).permit(:name, :position, :description)
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
