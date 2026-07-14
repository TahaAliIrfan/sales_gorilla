# Backs the Proposal Generator's multi-chat UI: persisted conversations, a
# per-chat turn endpoint, one-click "import all of a customer's data" as chat
# context, and kicking off the proposal build from a chat.
class ProposalChatsController < ApplicationController
  before_action :require_login
  before_action :set_chat, only: [:show, :destroy, :message, :import_customer, :generate]

  DEFAULT_HOURLY_RATE = 25

  # Sidebar list.
  def index
    chats = current_user.proposal_chats.where(kind: chat_kind).recent.limit(100)
    render json: { chats: chats.map { |c| chat_summary(c) } }
  end

  def create
    chat = current_user.proposal_chats.create!(kind: chat_kind)
    render json: chat_summary(chat)
  end

  # Full messages for rendering when a chat is opened.
  def show
    render json: {
      id: @chat.id,
      title: @chat.display_title,
      customer: @chat.customer && { id: @chat.customer_id, label: CustomerDossierService.new(@chat.customer).label },
      messages: @chat.messages.chronological.map { |m| message_json(m) }
    }
  end

  def destroy
    @chat.destroy
    render json: { success: true }
  end

  # One conversation turn (with optional uploaded file folded into the turn).
  def message
    text = params[:content].to_s.strip
    if params[:file].present?
      extracted = ProposalFileExtractor.extract(params[:file])
      note = extracted.present? ? "\n\n[Attached file: #{params[:file].original_filename}]\n#{extracted}" : "\n\n[Attached file: #{params[:file].original_filename} — couldn't read its text.]"
      text = "#{text}#{note}"
    end
    return render(json: { success: false, error: "Say something first." }, status: :unprocessable_entity) if text.blank?

    @chat.messages.create!(role: "user", content: text)
    @chat.ensure_title_from!(params[:content])

    reply = ProposalChatService.new(user: current_user, kind: @chat.kind).reply(@chat.reload.llm_history)
    @chat.messages.create!(role: "assistant", content: reply)
    render json: { success: true, reply: reply, title: @chat.display_title }
  rescue ProposalChatService::MissingApiKey
    render json: { success: false, error: "The AI assistant is not configured on this server." }, status: :service_unavailable
  rescue => e
    Rails.logger.error("Proposal chat message failed (chat #{@chat.id}): #{e.message}")
    render json: { success: false, error: "The assistant is unavailable right now. Please try again." }, status: :bad_gateway
  end

  # Pull everything we know about a customer into the chat as context.
  def import_customer
    customer = policy_scope(Customer).find_by(id: params[:customer_id])
    return render(json: { success: false, error: "Customer not found." }, status: :not_found) unless customer

    dossier = CustomerDossierService.new(customer)
    @chat.messages.create!(role: "context", content: "Imported CRM data for #{dossier.label}:\n\n#{dossier.build}")
    @chat.update!(customer_id: customer.id)
    @chat.ensure_title_from!("Proposal for #{customer.name}")
    render json: { success: true, label: dossier.label, title: @chat.display_title }
  rescue => e
    Rails.logger.error("Proposal chat import failed (chat #{@chat.id}): #{e.message}")
    render json: { success: false, error: "Couldn't import that customer's data." }, status: :internal_server_error
  end

  # Typeahead for the customer importer.
  def customer_search
    q = params[:q].to_s.strip
    return render(json: { customers: [] }) if q.blank?
    matches = policy_scope(Customer).search(q).order(Arel.sql("lead_score DESC NULLS LAST")).limit(10)
    render json: { customers: matches.map { |c| { id: c.id, name: c.name, company: c.company } } }
  end

  # Build the costed proposal from this chat (async worker; poll proposal_status).
  def generate
    @chat.kind == "odoo" ? generate_odoo : generate_cost
  rescue => e
    Rails.logger.error("Proposal chat generate failed (chat #{@chat.id}): #{e.message}")
    render json: { success: false, error: "Something went wrong starting the proposal. Please try again." }, status: :internal_server_error
  end

  private

  def generate_cost
    intake = ProposalIntakeService.new(user: current_user).extract(@chat.llm_history)
    if intake[:description].blank?
      render json: { success: false, error: "Tell me a bit more about the project first, then generate." }, status: :unprocessable_entity
      return
    end

    estimate = current_user.cost_estimates.new(
      app_type: intake[:app_type], description: intake[:description], scale: intake[:scale],
      include_design: intake[:include_design], hourly_rate: DEFAULT_HOURLY_RATE,
      customer_id: @chat.customer_id,
      customer_name: (@chat.customer&.name.presence || intake[:customer_name].presence || "Prospect"),
      project_name: intake[:project_name].presence, proposal_state: "generating"
    )
    estimate.save(validate: false)
    GenerateProposalPdfWorker.perform_async(estimate.id)
    render json: { success: true, estimate_id: estimate.id, status_url: proposal_status_cost_estimate_path(estimate) }
  end

  def generate_odoo
    spec = OdooProposalIntakeService.new(user: current_user).extract(@chat.llm_history)
    if spec[:selected_modules].blank? && spec[:custom_modules].blank?
      render json: { success: false, error: "Tell me which Odoo modules or needs to cover first, then generate." }, status: :unprocessable_entity
      return
    end

    proposal = current_user.odoo_proposals.new(
      deployment_type: spec[:deployment_type],
      num_users: spec[:num_users],
      selected_modules: spec[:selected_modules],
      custom_modules: spec[:custom_modules].map { |c| { "label" => c["name"], "impl_cost" => c["cost"].to_i, "description" => "" } },
      industry: spec[:industry].presence,
      company_size: spec[:company_size].presence,
      pain_points: spec[:pain_points].present? ? [spec[:pain_points]] : [],
      customer_id: @chat.customer_id,
      customer_name: (@chat.customer&.name.presence || spec[:customer_name].presence || "Prospect"),
      proposal_state: "generating"
    )
    proposal.implementation_fee = proposal.calculate_implementation_fee
    proposal.annual_hosting_cost = proposal.calculate_annual_hosting_cost
    proposal.save!
    GenerateOdooProposalWorker.perform_async(proposal.id)
    render json: { success: true, estimate_id: proposal.id, status_url: proposal_status_odoo_proposal_path(proposal) }
  end

  # cost | odoo, from the page that owns the chat.
  def chat_kind
    %w[cost odoo].include?(params[:kind]) ? params[:kind] : "cost"
  end

  def set_chat
    @chat = current_user.proposal_chats.find(params[:id])
  end

  def chat_summary(chat)
    { id: chat.id, title: chat.display_title, updated_at: chat.updated_at.strftime("%-d %b, %-l:%M %p") }
  end

  def message_json(m)
    { role: m.role, context: m.context?, content: m.context? ? context_label(m) : m.content }
  end

  # A context row renders as a subtle chip, not the raw dossier dump.
  def context_label(m)
    m.content.to_s[/\AImported CRM data for (.+?):/, 1] || "Imported customer data"
  end
end
