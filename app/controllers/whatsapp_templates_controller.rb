# Admin page for browsing and syncing the approved Twilio WhatsApp Content
# templates that the WhatsApp US chat composer can send. Templates are
# read-only here — creation/approval happens in Twilio's console.
class WhatsappTemplatesController < ApplicationController
  layout "tenant"
  before_action :require_login
  before_action :require_admin

  def index
    @templates       = WhatsappTemplate.ordered
    @approved_count  = @templates.count { |t| t.approval_status.to_s.downcase == 'approved' }
    @last_synced_at  = @templates.map(&:last_synced_at).compact.max
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
