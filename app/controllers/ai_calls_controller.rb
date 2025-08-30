class AiCallsController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_ai_conversation, only: [:show]

  def index
    @conversations = AiConversation.includes(:user, :customer).recent
    
    # Apply filters based on user role
    unless current_user&.admin?
      if current_user&.manager?
        # Managers can see conversations for themselves and their associates
        user_ids = [current_user.id] + current_user.associates.pluck(:id)
        @conversations = @conversations.where(user_id: user_ids)
      else
        # Associates can only see their own conversations
        @conversations = @conversations.for_user(current_user)
      end
    end
    
    # Add pagination
    @conversations = @conversations.page(params[:page]).per(20)
  end

  def show
    # Already set by before_action
  end

  def sync
    begin
      new_conversations = ElevenLabsService.sync_conversations
      
      if new_conversations.any?
        flash[:notice] = "Successfully synced #{new_conversations.length} new AI conversations."
      else
        flash[:info] = "No new conversations found to sync."
      end
    rescue => e
      Rails.logger.error("Failed to sync conversations: #{e.message}")
      flash[:alert] = "Failed to sync conversations: #{e.message}"
    end
    
    redirect_to ai_calls_path
  end

  def audio
    ai_conversation = AiConversation.find_by(conversation_id: params[:id])
    
    unless ai_conversation
      head :not_found
      return
    end
    
    audio_data = ElevenLabsService.fetch_conversation_audio(params[:id])
    
    if audio_data
      send_data audio_data,
                type: 'audio/mpeg',
                disposition: 'inline',
                filename: "conversation_#{params[:id]}.mp3"
    else
      head :not_found
    end
  rescue => e
    Rails.logger.error "Failed to fetch audio: #{e.message}"
    head :internal_server_error
  end

  private

  def set_ai_conversation
    @conversation = AiConversation.includes(:user, :customer).find_by(conversation_id: params[:id])
    
    unless @conversation
      flash[:alert] = "AI conversation not found."
      redirect_to ai_calls_path
    end
  end
end