class OdooProposalsController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_proposal, only: [:show, :edit, :update, :destroy, :download_pdf, :generate_narrative, :regenerate_section, :update_narrative, :proposal_status]

  def index
    # Admins see every rep's proposals; everyone else sees their own.
    scope = current_user.admin? ? OdooProposal.all : current_user.odoo_proposals
    @proposals = scope.includes(:customer).order(created_at: :desc)
  end

  # Poll target for a chat-driven Odoo proposal build.
  def proposal_status
    ready = @proposal.proposal_state == "ready"
    mods = @proposal.selected_modules.size + Array(@proposal.custom_modules).size
    render json: {
      state: @proposal.proposal_state,
      ready: ready,
      failed: @proposal.proposal_state == "failed",
      project_name: @proposal.display_name,
      summary: "#{mods} modules · PKR #{ActiveSupport::NumberHelper.number_to_delimited(@proposal.total_cost)}",
      download_url: (ready ? download_pdf_odoo_proposal_path(@proposal) : nil)
    }
  end

  def new
    @proposal = OdooProposal.new
    @customers = customers_for_select
  end

  def create
    @proposal = current_user.odoo_proposals.build(proposal_params)
    apply_array_params(@proposal)
    @proposal.implementation_fee = @proposal.calculate_implementation_fee
    @proposal.annual_hosting_cost = @proposal.calculate_annual_hosting_cost

    if @proposal.save
      status = generate_narrative_for(@proposal)
      flash_key = status == :ok ? :notice : :alert
      message =
        case status
        when :ok     then 'Proposal saved and Claude narrative generated.'
        when :no_key then 'Proposal saved. AI narrative skipped — Anthropic API key not configured.'
        else              'Proposal saved. AI narrative failed to generate — open the proposal and click Generate to retry.'
        end
      redirect_to odoo_proposal_path(@proposal), flash_key => message
    else
      @customers = customers_for_select
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @customers = customers_for_select
  end

  def update
    @proposal.assign_attributes(proposal_params)
    apply_array_params(@proposal)
    @proposal.implementation_fee = @proposal.calculate_implementation_fee
    @proposal.annual_hosting_cost = @proposal.calculate_annual_hosting_cost

    if @proposal.save
      status = generate_narrative_for(@proposal)
      flash_key = status == :ok ? :notice : :alert
      message =
        case status
        when :ok     then 'Proposal updated and Claude narrative regenerated.'
        when :no_key then 'Proposal updated. AI narrative skipped — Anthropic API key not configured.'
        else              'Proposal updated. AI narrative failed to regenerate — click Regenerate on the proposal to retry.'
        end
      redirect_to odoo_proposal_path(@proposal), flash_key => message
    else
      @customers = customers_for_select
      render :edit, status: :unprocessable_entity
    end
  end

  # POST /odoo_proposals/analyze
  # Accepts text and/or an uploaded file (PDF, image, .docx, .txt).
  # Returns JSON: modules[], custom_modules[], industry, company_size, pain_points[].
  def analyze
    text  = params[:text].to_s
    file  = params[:file]

    if text.blank? && file.blank?
      return render json: { error: 'Provide text or upload a file.' }, status: :unprocessable_entity
    end

    service = OdooProposalDetectionService.new(text: text, file: file)
    result  = service.analyze

    if result
      render json: result
    else
      render json: { error: service.error || 'AI analysis failed. Try again.' }, status: :unprocessable_entity
    end
  end

  def show
  end

  def destroy
    @proposal.destroy
    redirect_to odoo_proposals_path, notice: 'Proposal deleted.'
  end

  def download_pdf
    pdf_bytes = OdooProposalHtmlPdfService.new(@proposal).generate

    client_name = @proposal.display_name.gsub(/[^a-zA-Z0-9\s]/, '').strip.gsub(/\s+/, '_')
    filename = "Odoo_Proposal_#{client_name}_#{Date.current.strftime('%Y%m%d')}.pdf"

    send_data pdf_bytes,
      filename: filename,
      type: 'application/pdf',
      disposition: 'attachment'
  end

  # AJAX endpoint for live cost calculation
  def calculate
    modules = Array(params[:modules]).reject(&:blank?)
    deployment = params[:deployment_type]
    tier = params[:hosting_tier]

    all_mods = OdooProposal::MODULES.values.flatten
    impl_fee = modules.sum { |k| all_mods.find { |m| m[:key] == k }&.dig(:impl_cost).to_i }

    hosting = if deployment == 'online'
      0
    else
      OdooProposal::HOSTING_TIERS[tier]&.dig(:annual_pkr).to_i
    end

    render json: {
      implementation_fee: impl_fee,
      annual_hosting_cost: hosting,
      total: impl_fee + hosting
    }
  end

  # POST /odoo_proposals/:id/generate_narrative
  def generate_narrative
    result = OdooProposalNarrativeService.new(@proposal).generate_all

    if result
      @proposal.update(
        claude_summary: result['summary'],
        claude_rationale: result['rationale'],
        claude_module_justifications: result['module_justifications'],
        claude_next_steps: result['next_steps'],
        narrative_generated_at: Time.current
      )
      redirect_to odoo_proposal_path(@proposal), notice: 'AI narrative generated.'
    else
      redirect_to odoo_proposal_path(@proposal),
        alert: 'Could not generate narrative. Check the Anthropic API key and try again.'
    end
  end

  # POST /odoo_proposals/:id/regenerate_section
  def regenerate_section
    section = params[:section].to_s
    unless OdooProposalNarrativeService::SECTIONS.include?(section)
      redirect_to odoo_proposal_path(@proposal), alert: 'Unknown section.' and return
    end

    result = OdooProposalNarrativeService.new(@proposal).regenerate_section(section)

    if result
      column = case section
      when 'summary'               then :claude_summary
      when 'rationale'             then :claude_rationale
      when 'module_justifications' then :claude_module_justifications
      when 'next_steps'            then :claude_next_steps
      end
      @proposal.update(column => result, narrative_generated_at: Time.current)
      redirect_to odoo_proposal_path(@proposal), notice: "#{section.humanize} regenerated."
    else
      redirect_to odoo_proposal_path(@proposal), alert: 'Regeneration failed. Try again.'
    end
  end

  # PATCH /odoo_proposals/:id/update_narrative
  def update_narrative
    justifications = params.dig(:odoo_proposal, :claude_module_justifications)
    permitted = params.require(:odoo_proposal).permit(
      :claude_summary, :claude_rationale, :claude_next_steps
    )
    permitted[:claude_module_justifications] = justifications.to_unsafe_h if justifications.respond_to?(:to_unsafe_h)

    if @proposal.update(permitted)
      redirect_to odoo_proposal_path(@proposal), notice: 'Narrative saved.'
    else
      redirect_to odoo_proposal_path(@proposal), alert: 'Could not save narrative.'
    end
  end

  private

  def generate_narrative_for(proposal)
    api_key = Rails.application.credentials.dig(:ANTHROPIC_API_KEY) || ENV['ANTHROPIC_API_KEY']
    return :no_key if api_key.blank?

    result = OdooProposalNarrativeService.new(proposal).generate_all
    return :failed unless result

    proposal.update(
      claude_summary: result['summary'],
      claude_rationale: result['rationale'],
      claude_module_justifications: result['module_justifications'],
      claude_next_steps: result['next_steps'],
      narrative_generated_at: Time.current
    )
    :ok
  end

  def set_proposal
    scope = current_user.admin? ? OdooProposal.all : current_user.odoo_proposals
    @proposal = scope.find(params[:id])
  end

  def customers_for_select
    if current_user.admin?
      Customer.order(:name)
    elsif current_user.manager?
      associate_ids = current_user.associates.pluck(:id) + [current_user.id]
      Customer.where(user_id: associate_ids).order(:name)
    else
      current_user.customers.order(:name)
    end
  end

  def proposal_params
    params.require(:odoo_proposal).permit(
      :customer_id, :customer_name, :deployment_type,
      :hosting_tier, :num_users, :notes,
      :industry, :company_size
    )
  end

  def apply_array_params(proposal)
    proposal.selected_modules = Array(params.dig(:odoo_proposal, :selected_modules)).reject(&:blank?)
    proposal.pain_points      = Array(params.dig(:odoo_proposal, :pain_points)).reject(&:blank?)
    proposal.custom_modules   = sanitize_custom_modules(params.dig(:odoo_proposal, :custom_modules))
  end

  def sanitize_custom_modules(raw)
    return [] if raw.blank?

    entries = raw.respond_to?(:values) ? raw.values : Array(raw)
    entries.filter_map do |entry|
      h = entry.respond_to?(:to_unsafe_h) ? entry.to_unsafe_h : entry
      next nil unless h.is_a?(Hash)
      label = h['label'].to_s.strip
      next nil if label.empty?
      record = {
        'label'       => label,
        'description' => h['description'].to_s.strip,
        'impl_cost'   => h['impl_cost'].to_i
      }
      hours = h['hours'].to_i
      record['hours'] = hours if hours.positive?
      record
    end
  end
end
