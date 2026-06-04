class CampaignExecution < ApplicationRecord
  acts_as_tenant(:organization)

  STATUSES = %w[pending processing completed failed].freeze

  belongs_to :campaign
  belongs_to :customer

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :scheduled_at, presence: true
  validates :customer_id, uniqueness: { scope: :campaign_id }

  scope :pending, -> { where(status: "pending") }
  scope :processing, -> { where(status: "processing") }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }

  def execute!
    return unless pending?

    update(status: "processing")

    begin
      # Check if customer has WhatsApp chat ID
      if customer.whatsapp_chat_id.blank?
        raise "Customer #{customer.name} does not have a WhatsApp chat ID"
      end

      # Process template variables in message
      personalized_message = process_template_variables(campaign.message)

      # Send WhatsApp message using WhatsappMessageService
      service = WhatsappMessageService.new
      result = service.send_message(
        customer.whatsapp_chat_id,
        personalized_message,
        customer
      )

      if result[:success]
        update(
          status: "completed",
          executed_at: Time.current
        )
      else
        raise result[:error] || "Unknown error occurred"
      end
    rescue StandardError => e
      update(
        status: "failed",
        error_message: e.message,
        executed_at: Time.current
      )
    ensure
      # Check if campaign is complete
      campaign.check_completion!
    end
  end

  def pending?
    status == "pending"
  end

  def processing?
    status == "processing"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  private

  def process_template_variables(message)
    return message if message.blank?

    # Define available template variables and their values
    variables = {
      "customer_name" => customer.name || "",
      "name" => customer.name || "",
      "email" => customer.email || "",
      "phone" => customer.phone || "",
      "company" => customer.company || "",
      "lead_source" => customer.lead_source || "",
      "status" => customer.status || ""
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
