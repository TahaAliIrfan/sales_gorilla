class AiCallsController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :require_admin
  before_action :set_ai_conversation, only: [:show]

  def index
    @conversations = AiConversation.includes(:user, :customer).recent.page(params[:page]).per(20)
  end

  def show
    # Already set by before_action
    Rails.logger.info("AI Conversation Show: #{@conversation.conversation_id}")
    Rails.logger.info("Has transcript: #{@conversation.has_transcript?}")
    Rails.logger.info("Transcript data: #{@conversation.transcript.inspect}")
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
    Rails.logger.info("Audio request for conversation ID: #{params[:id]}")
    
    ai_conversation = AiConversation.find_by(conversation_id: params[:id])
    
    unless ai_conversation
      Rails.logger.error("AI conversation not found: #{params[:id]}")
      head :not_found
      return
    end
    
    Rails.logger.info("Found conversation: #{ai_conversation.conversation_id}, status: #{ai_conversation.status}")
    
    audio_data = ElevenLabsService.fetch_conversation_audio(params[:id])
    
    if audio_data
      Rails.logger.info("Successfully fetched audio data, size: #{audio_data.size} bytes")
      send_data audio_data,
                type: 'audio/mpeg',
                disposition: 'inline',
                filename: "conversation_#{params[:id]}.mp3"
    else
      Rails.logger.error("No audio data returned from API")
      head :not_found
    end
  rescue => e
    Rails.logger.error "Failed to fetch audio: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
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