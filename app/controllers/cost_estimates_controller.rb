class CostEstimatesController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_cost_estimate, only: [:show, :destroy, :generate_proposal]
  
  DEFAULT_HOURLY_RATE = 25

  # Proposal Generator landing = the chat, plus a list of recent proposals.
  # Admins see everyone's proposals; everyone else sees their own.
  def index
    scope = current_user.admin? ? CostEstimate.all : current_user.cost_estimates
    @recent_estimates = scope.order(created_at: :desc).limit(current_user.admin? ? 50 : 15)
  end

  def show
  end

  # Conversational scoping turn. Accepts the running history and an optional
  # uploaded file, whose text we fold into the latest user message.
  def chat
    history = chat_history_param
    if params[:file].present?
      extracted = ProposalFileExtractor.extract(params[:file])
      history = fold_file_into_last_user_turn(history, params[:file].original_filename, extracted)
    end

    reply = ProposalChatService.new(user: current_user).reply(history)
    render json: { success: true, reply: reply }
  rescue ProposalChatService::MissingApiKey
    render json: { success: false, error: "The AI assistant is not configured on this server." }, status: :service_unavailable
  rescue ArgumentError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error("Proposal chat failed for user #{current_user.id}: #{e.message}")
    render json: { success: false, error: "The assistant is unavailable right now. Please try again." }, status: :bad_gateway
  end

  # Kick off the full proposal build from the conversation. Extraction is quick;
  # the heavy estimate + narrative + PDF runs in a background worker (can take
  # ~60-90s), so we return an id the chat polls via #proposal_status.
  def generate_from_chat
    history = chat_history_param
    intake = ProposalIntakeService.new(user: current_user).extract(history)

    if intake[:description].blank?
      render json: { success: false, error: "I need a bit more about the project first. Describe what they want to build, then try again." }, status: :unprocessable_entity
      return
    end

    # Created without total_hours yet (the worker fills it), so skip validation
    # on this initial "generating" row. customer_name defaults so the record can
    # still validate later.
    estimate = current_user.cost_estimates.new(
      app_type: intake[:app_type],
      description: intake[:description],
      scale: intake[:scale],
      include_design: intake[:include_design],
      hourly_rate: params[:hourly_rate].presence&.to_f || DEFAULT_HOURLY_RATE,
      customer_name: intake[:customer_name].presence || "Prospect",
      project_name: intake[:project_name].presence,
      proposal_state: "generating"
    )
    estimate.save(validate: false)

    GenerateProposalPdfWorker.perform_async(estimate.id)
    render json: { success: true, estimate_id: estimate.id, status_url: proposal_status_cost_estimate_path(estimate) }
  rescue => e
    Rails.logger.error("generate_from_chat failed for user #{current_user.id}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    render json: { success: false, error: "Something went wrong starting the proposal. Please try again." }, status: :internal_server_error
  end

  # Poll target for the async build.
  def proposal_status
    estimate = current_user.cost_estimates.find(params[:id])
    ready = estimate.proposal_state == "ready" && estimate.pdf_file.attached?
    render json: {
      state: estimate.proposal_state,
      ready: ready,
      failed: estimate.proposal_state == "failed",
      project_name: estimate.app_name.presence || estimate.project_name,
      summary: ([("#{estimate.total_hours}h" if estimate.total_hours.present?), (estimate.formatted_total_cost if estimate.total_hours.present?)].compact.join(" · ")),
      download_url: (rails_blob_path(estimate.pdf_file, disposition: "attachment", only_path: true) if ready)
    }
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
        error: analysis_result[:error] || 'Failed to analyze project requirements'
      }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @cost_estimate.destroy
    redirect_to cost_estimates_path, notice: 'Cost estimate was successfully deleted.'
  end

  def resend
    cost_estimate = CostEstimate.find(params[:id])

    if cost_estimate.customer&.email.blank?
      redirect_back fallback_location: cost_estimates_path,
        alert: 'Cannot resend: this estimate has no customer email on file.'
      return
    end

    SendCostEstimatePdfJob.perform_async(cost_estimate.id)
    redirect_back fallback_location: cost_estimates_path,
      notice: "Estimate is being resent to #{cost_estimate.customer.email}."
  end
  
  def generate_proposal
    # Make sure the proposal carries an AI-proposed product name + narrative,
    # same as the emailed version. Non-fatal: falls back to customer app name.
    begin
      @cost_estimate.ensure_proposal_content!
    rescue => e
      Rails.logger.error("Proposal content generation failed (#{e.message}) — continuing")
    end

    pdf_binary = begin
      CostEstimateHtmlPdfService.new(@cost_estimate).generate
    rescue => e
      Rails.logger.error("HTML PDF generation failed (#{e.message}), falling back to Prawn")
      ProposalGenerationService.new(@cost_estimate).generate_pdf.render
    end

    filename = "#{@cost_estimate.app_type}_proposal_#{Date.current.strftime('%Y%m%d')}.pdf"

    send_data pdf_binary,
      filename: filename,
      type: 'application/pdf',
      disposition: 'attachment'
  end
  
  private

  # Accepts messages either as a JSON string (multipart form, so a file can ride
  # along) or as a parsed array (JSON request body).
  def chat_history_param
    raw = params[:messages]
    if raw.is_a?(String)
      raw = (JSON.parse(raw) rescue [])
    elsif raw.respond_to?(:map)
      raw = raw.map { |m| m.respond_to?(:permit) ? m.permit(:role, :content).to_h : m }
    end
    Array(raw)
  end

  # Append the uploaded file's extracted text to the most recent user turn so the
  # model reads it as part of what the rep is saying.
  def fold_file_into_last_user_turn(history, filename, extracted)
    note = if extracted.present?
      "\n\n[Attached file: #{filename}]\n#{extracted}"
    else
      "\n\n[Attached file: #{filename} — couldn't read its text; ask me about it.]"
    end
    last = history.reverse.find { |m| (m["role"] || m[:role]) == "user" }
    if last
      last["content"] = "#{last["content"] || last[:content]}#{note}"
    else
      history << { "role" => "user", "content" => note.strip }
    end
    history
  end

  def set_cost_estimate
    scope = current_user.admin? ? CostEstimate.all : current_user.cost_estimates
    @cost_estimate = scope.find(params[:id])
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