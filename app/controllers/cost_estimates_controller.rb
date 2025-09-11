class CostEstimatesController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_cost_estimate, only: [:show, :destroy, :generate_proposal]
  
  def index
    @cost_estimates = current_user.cost_estimates.order(created_at: :desc).page(params[:page])
  end
  
  def show
  end
  
  def create
    @cost_estimate = current_user.cost_estimates.build(cost_estimate_params)
    
    # Analyze project with Claude AI to get features and estimates
    ai_service = ClaudeProjectAnalysisService.new
    analysis_result = ai_service.analyze_project(
      app_type: @cost_estimate.app_type,
      description: @cost_estimate.description,
      scale: @cost_estimate.scale
    )
    
    if analysis_result[:success]
      @cost_estimate.features = analysis_result[:features]
      @cost_estimate.total_hours = analysis_result[:total_hours]
      # hourly_rate is already set from the form
      
      if @cost_estimate.save
        render json: {
          success: true,
          features: @cost_estimate.features,
          total_hours: @cost_estimate.total_hours,
          hourly_rate: @cost_estimate.hourly_rate,
          total_cost: @cost_estimate.total_cost,
          formatted_cost: @cost_estimate.formatted_total_cost,
          estimate_id: @cost_estimate.id
        }
      else
        render json: {
          success: false,
          errors: @cost_estimate.errors.full_messages
        }, status: :unprocessable_entity
      end
    else
      render json: {
        success: false,
        error: analysis_result[:error] || 'Failed to analyze project requirements'
      }, status: :unprocessable_entity
    end
  end
  
  def analyze
    # AJAX endpoint for getting analysis without saving
    ai_service = ClaudeProjectAnalysisService.new
    analysis_result = ai_service.analyze_project(
      app_type: params[:app_type],
      description: params[:description],
      scale: params[:scale]
    )
    
    if analysis_result[:success]
      hourly_rate = params[:hourly_rate].to_f
      total_cost = analysis_result[:total_hours] * hourly_rate
      
      render json: {
        success: true,
        features: analysis_result[:features],
        total_hours: analysis_result[:total_hours],
        hourly_rate: hourly_rate,
        total_cost: total_cost,
        formatted_cost: "$#{total_cost.round(2)}"
      }
    else
      render json: {
        success: false,
        error: analysis_result[:error] || 'Failed to analyze project requirements'
      }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @cost_estimate.destroy
    redirect_to cost_estimates_path, notice: 'Cost estimate was successfully deleted.'
  end
  
  def generate_proposal
    proposal_service = ProposalGenerationService.new(@cost_estimate)
    pdf = proposal_service.generate_pdf
    
    filename = "#{@cost_estimate.app_type}_proposal_#{Date.current.strftime('%Y%m%d')}.pdf"
    
    send_data pdf.render, 
      filename: filename,
      type: 'application/pdf',
      disposition: 'attachment'
  end
  
  private
  
  def set_cost_estimate
    @cost_estimate = current_user.cost_estimates.find(params[:id])
  end
  
  def cost_estimate_params
    params.require(:cost_estimate).permit(:app_type, :description, :scale, :hourly_rate)
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