# Admin page for browsing and syncing the approved Twilio WhatsApp Content
# templates that the WhatsApp US chat composer can send. Templates are
# read-only here — creation/approval happens in Twilio's console.
class WhatsappTemplatesController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :require_admin

  def index
    @templates       = WhatsappTemplate.ordered
    @approved_count  = @templates.count { |t| t.approval_status.to_s.downcase == 'approved' }
    @last_synced_at  = @templates.map(&:last_synced_at).compact.max
  end

  # GET /whatsapp_templates/new
  def new
    @friendly_name = ''
    @body          = ''
    @language      = 'en'
    @category      = 'UTILITY'
  end

  # POST /whatsapp_templates
  def create
    @friendly_name = params[:friendly_name].to_s.strip
    @body          = params[:body].to_s
    @language      = params[:language].presence || 'en'
    @category      = params[:category].presence || 'UTILITY'

    result = TwilioWhatsappTemplatesService.new.create_template(
      friendly_name: @friendly_name,
      body: @body,
      category: @category,
      language: @language
    )

    if result[:success]
      notice = "Template submitted to Twilio and sent to Meta for approval. It will show as Approved here once Meta approves it, then hit Sync."
      notice += " (Approval submit warning: #{result[:approval_error]})" if result[:approval_error].present?
      redirect_to whatsapp_templates_path, notice: notice
    else
      flash.now[:alert] = "Could not create template: #{result[:error]}"
      render :new, status: :unprocessable_entity
    end
  end

  # DELETE /whatsapp_templates/:id
  def destroy
    template = WhatsappTemplate.find(params[:id])
    result = TwilioWhatsappTemplatesService.new.delete_template(template.content_sid)

    if result[:success]
      redirect_to whatsapp_templates_path, notice: "Template deleted from Twilio."
    else
      redirect_to whatsapp_templates_path, alert: "Delete failed: #{result[:error]}"
    end
  end

  # POST /whatsapp_templates/sync
  def sync
    result = TwilioWhatsappTemplatesService.new.sync!
    if result[:success]
      redirect_to whatsapp_templates_path,
                  notice: "Synced #{result[:synced]} approved template(s) from Twilio (skipped #{result[:skipped]} non-approved)."
    else
      redirect_to whatsapp_templates_path, alert: "Sync failed: #{result[:error]}"
    end
  end
end
