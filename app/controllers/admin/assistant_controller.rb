module Admin
  # CRM-wide AI assistant, admin only. The page (index) shows the admin's saved
  # thread; chat (POST) answers a turn via AdminAssistantService and persists it.
  class AssistantController < ApplicationController
    layout 'dashboard'

    before_action :require_login
    before_action :require_admin

    def index
      @history = current_user.admin_assistant_messages
                             .chronological
                             .last(100)
                             .map { |m| { role: m.role, content: m.content } }
    end

    def chat
      history = params[:messages]
      history = history.map { |m| m.permit(:role, :content).to_h } if history.respond_to?(:map)

      reply = AdminAssistantService.new(current_user).reply(history)
      persist_turn(history, reply)
      render json: { success: true, reply: reply }
    rescue AdminAssistantService::MissingApiKey
      render json: { success: false, error: "The AI assistant is not configured on this server." }, status: :service_unavailable
    rescue AdminAssistantService::RateLimited => e
      render json: { success: false, error: e.message }, status: :too_many_requests
    rescue ArgumentError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue Timeout::Error
      render json: { success: false, error: "That took too long. Try a narrower question." }, status: :gateway_timeout
    rescue => e
      Rails.logger.error("Admin AI assistant failed for user #{current_user.id}: #{e.message}")
      render json: { success: false, error: "The AI assistant is unavailable right now. Please try again." }, status: :bad_gateway
    end

    # Clear the admin's saved thread so they can start fresh.
    def reset
      current_user.admin_assistant_messages.delete_all
      render json: { success: true }
    end

    private

    # Persist the newest user turn + the assistant reply. Earlier turns in the
    # posted history are already stored. Never let persistence break the reply.
    def persist_turn(history, reply)
      last = Array(history).last
      return if last.blank?

      role = last["role"] || last[:role]
      content = (last["content"] || last[:content]).to_s.strip
      return unless role == "user" && content.present?

      current_user.admin_assistant_messages.create!(role: "user", content: content)
      current_user.admin_assistant_messages.create!(role: "assistant", content: reply)
    rescue => e
      Rails.logger.error("Failed to persist admin AI chat for user #{current_user.id}: #{e.message}")
    end
  end
end
