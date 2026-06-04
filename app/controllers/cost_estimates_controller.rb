class CostEstimatesController < ApplicationController
  layout "tenant"
  before_action :require_login
  before_action :set_cost_estimate, only: [ :show, :destroy, :generate_proposal ]

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
      scale: @cost_estimate.scale,
      include_design: @cost_estimate.include_design
    )

    if analysis_result[:success]
      @cost_estimate.features = analysis_result[:features]
      @cost_estimate.total_hours = analysis_result[:total_hours]
      @cost_estimate.project_name = analysis_result[:project_name]
      @cost_estimate.project_overview = analysis_result[:project_overview]
      @cost_estimate.technical_information_summary = analysis_result[:technical_information_summary]
      @cost_estimate.estimated_timeline_weeks = analysis_result[:estimated_timeline_weeks]
      @cost_estimate.team_composition = analysis_result[:team_composition]
      @cost_estimate.development_methodology = analysis_result[:development_methodology]
      @cost_estimate.key_technology_areas = analysis_result[:key_technology_areas]
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
        error: analysis_result[:error] || "Failed to analyze project requirements"
      }, status: :unprocessable_entity
    end
  end

  def analyze
    # AJAX endpoint for getting analysis without saving
    ai_service = ClaudeProjectAnalysisService.new
    analysis_result = ai_service.analyze_project(
      app_type: params[:app_type],
      description: params[:description],
      scale: params[:scale],
      include_design: params[:include_design] == true
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
        error: analysis_result[:error] || "Failed to analyze project requirements"
      }, status: :unprocessable_entity
    end
  end

  def destroy
    @cost_estimate.destroy
    redirect_to cost_estimates_path, notice: "Cost estimate was successfully deleted."
  end

  def resend
    cost_estimate = CostEstimate.find(params[:id])

    if cost_estimate.customer&.email.blank?
      redirect_back fallback_location: cost_estimates_path,
        alert: "Cannot resend: this estimate has no customer email on file."
      return
    end

    SendCostEstimatePdfJob.perform_async(cost_estimate.id)
    redirect_back fallback_location: cost_estimates_path,
      notice: "Estimate is being resent to #{cost_estimate.customer.email}."
  end

  def generate_proposal
    proposal_service = ProposalGenerationService.new(@cost_estimate)
    pdf = proposal_service.generate_pdf

    filename = "#{@cost_estimate.app_type}_proposal_#{Date.current.strftime('%Y%m%d')}.pdf"

    send_data pdf.render,
      filename: filename,
      type: "application/pdf",
      disposition: "attachment"
  end

  private

  def set_cost_estimate
    @cost_estimate = current_user.cost_estimates.find(params[:id])
  end

  def cost_estimate_params
    params.require(:cost_estimate).permit(:app_type, :description, :scale, :hourly_rate, :include_design, :customer_id, :customer_name)
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
