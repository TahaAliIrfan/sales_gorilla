class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def message_received
    if params[:event] != 'message'
      return render json: { success: false, error: "Unsupported event type" }, status: :bad_request
    end

    message_data = params[:data]

    if message_data.blank? || message_data[:message].blank?
      return render json: { success: false, error: "Missing message data" }, status: :bad_request
    end

    chat_id = message_data.dig(:message, :from)

    if chat_id.blank?
      return render json: { success: false, error: "Missing chat ID" }, status: :bad_request
    end

    customer = Customer.find_by(whatsapp_chat_id: chat_id)

    if customer.nil?
      # Initiate background job for customer analysis
      message_body = message_data.dig(:message, :body).to_s
      WhatsappMessageAnalysisWorker.perform_async(chat_id, message_body)

      customer = Customer.create(whatsapp_chat_id: chat_id, name: 'Not Applicable', phone: chat_id.gsub(/@c\.us$/, ''), lead_source: 'WA')
    end

    begin
      whatsapp_message = WhatsappMessage.import_from_api(customer, message_data)

      ActionCable.server.broadcast(
        "chat_#{chat_id}",
        { 
          message: message_data[:message], 
          fromMe: false
        }
      )
      
      # Create notification for assigned user if exists
      create_notification_for_message(customer, whatsapp_message) if whatsapp_message.present?
      
      # Return success response
      render json: { success: true }, status: :ok
    rescue => e
      Rails.logger.error("Failed to process WhatsApp message: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
  end
  
  private
  
  def create_notification_for_message(customer, message)
    # If customer has an assigned user, create a notification
    if customer.user.present?
      # Create notification for the assigned user
      message_preview = message.body.truncate(50) # Limit message preview to 50 chars
      
      Notification.create!(
        user: customer.user,
        content: "New message from #{customer.name}: #{message_preview}",
        notification_type: 'message',
        resource: message,
        read: false
      )
      
      # Send email notification with cooldown protection (max 1 email per customer per 5 minutes)
      cooldown_key = "whatsapp_email_#{customer.id}_#{customer.user.id}"
      last_email_time = Rails.cache.read(cooldown_key)
      
      if last_email_time.nil? || last_email_time < 5.minutes.ago
        Rails.logger.info("Sending WhatsApp email notification for customer #{customer.id} to user #{customer.user.id}")
        UserMailer.whatsapp_message_notification(customer.user, customer, message.body).deliver_now
        Rails.cache.write(cooldown_key, Time.current, expires_in: 5.minutes)
      else
        Rails.logger.info("Skipping WhatsApp email notification for customer #{customer.id} - cooldown active (last sent: #{last_email_time})")
      end
    end
  end
end 