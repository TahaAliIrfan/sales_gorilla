class CampaignExecution < ApplicationRecord
  STATUSES = %w[pending processing completed failed].freeze

  belongs_to :campaign
  belongs_to :customer

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :scheduled_at, presence: true
  validates :customer_id, uniqueness: { scope: :campaign_id }

  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }

  def execute!
    return unless pending?

    update(status: 'processing')

    begin
      # Twilio sends to the phone number, not a green-api chat id.
      if customer.phone.blank?
        raise "Customer #{customer.name} does not have a phone number"
      end

      template = campaign.template
      raise "Campaign template is missing or no longer approved" if template.nil?

      # Resolve each template variable value per recipient, so a value like
      # "{{customer_name}}" becomes this customer's name before Twilio substitutes it.
      variables = resolve_content_variables

      result = TwilioWhatsappService.new.send_template(
        to_phone: customer.phone,
        content_sid: template.content_sid,
        content_variables: variables
      )

      if result[:success]
        persist_outbound(result[:sid], result[:status], template.render_body(variables))
        update(status: 'completed', executed_at: Time.current)
      else
        raise result[:error] || 'Unknown error occurred'
      end
    rescue StandardError => e
      update(
        status: 'failed',
        error_message: e.message,
        executed_at: Time.current
      )
    ensure
      # Check if campaign is complete
      campaign.check_completion!
    end
  end

  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  private

  # Build the content_variables hash Twilio expects, resolving per-customer
  # tokens ({{customer_name}} etc.) inside each variable value.
  def resolve_content_variables
    (campaign.content_variables || {}).each_with_object({}) do |(key, value), out|
      out[key.to_s] = process_template_variables(value.to_s)
    end
  end

  # Record the send in the Twilio whatsapp_messages channel so the status
  # callback can update it and it shows in the customer's WhatsApp US thread.
  def persist_outbound(sid, status, body)
    customer.whatsapp_messages.create!(
      message_id: sid,
      remote_id:  customer.phone,
      body:       body,
      direction:  'outbound',
      status:     status || 'queued',
      timestamp:  Time.current,
      metadata:   {
        provider: 'twilio',
        to: "whatsapp:#{customer.phone}",
        from: TwilioWhatsappService::FROM,
        campaign_id: campaign_id,
        sent_by_user_id: campaign.user_id
      }
    )
  rescue StandardError => e
    Rails.logger.error("[CampaignExecution ##{id}] persist_outbound failed: #{e.message}")
  end

  def process_template_variables(message)
    return message if message.blank?

    # Define available template variables and their values
    variables = {
      'customer_name' => customer.name || '',
      'name' => customer.name || '',
      'email' => customer.email || '',
      'phone' => customer.phone || '',
      'company' => customer.company || '',
      'lead_source' => customer.lead_source || '',
      'status' => customer.status || ''
    }

    # Replace all {{variable}} patterns with actual values
    processed_message = message.dup
    variables.each do |key, value|
      processed_message.gsub!(/\{\{#{key}\}\}/i, value.to_s)
      processed_message.gsub!(/\{\{\s*#{key}\s*\}\}/i, value.to_s) # Handle spaces
    end

    processed_message
  end
end
