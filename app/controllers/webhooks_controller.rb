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
      return render json: { success: false, error: "Customer not found" }, status: :not_found
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
    end
  end
end 