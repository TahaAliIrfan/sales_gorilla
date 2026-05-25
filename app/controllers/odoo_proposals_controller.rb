class OdooProposalsController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_proposal, only: [:show, :destroy, :download_pdf]

  def index
    @proposals = current_user.odoo_proposals.includes(:customer).order(created_at: :desc)
  end

  def new
    @proposal = OdooProposal.new
    @customers = customers_for_select
  end

  def create
    @proposal = current_user.odoo_proposals.build(proposal_params)
    @proposal.selected_modules = Array(params[:odoo_proposal][:selected_modules]).reject(&:blank?)
    @proposal.implementation_fee = @proposal.calculate_implementation_fee
    @proposal.annual_hosting_cost = @proposal.calculate_annual_hosting_cost

    if @proposal.save
      redirect_to odoo_proposal_path(@proposal), notice: 'Proposal saved successfully.'
    else
      @customers = customers_for_select
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def destroy
    @proposal.destroy
    redirect_to odoo_proposals_path, notice: 'Proposal deleted.'
  end

  def download_pdf
    service = OdooProposalPdfService.new(@proposal)
    pdf = service.generate

    client_name = @proposal.display_name.gsub(/[^a-zA-Z0-9\s]/, '').strip.gsub(/\s+/, '_')
    filename = "Odoo_Proposal_#{client_name}_#{Date.current.strftime('%Y%m%d')}.pdf"

    send_data pdf.render,
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

  private

  def set_proposal
    @proposal = current_user.odoo_proposals.find(params[:id])
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
      :hosting_tier, :num_users, :notes
    )
  end
end
