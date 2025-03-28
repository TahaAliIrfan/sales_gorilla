require 'json'

class RecordingsController < ApplicationController
  before_action :require_login
  before_action :require_admin, except: [:transcript]
  layout 'dashboard'
  before_action :set_recording, only: [:show, :transcript, :download]

  def index
    @recordings = Recording.includes(:customer, :user).recent
    
    # Apply filters if provided
    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date]).beginning_of_day
      end_date = Date.parse(params[:end_date]).end_of_day
      @recordings = @recordings.where(date: start_date..end_date)
    end
    
    if params[:customer_id].present?
      @recordings = @recordings.where(customer_id: params[:customer_id])
    end
    
    if params[:caller_id].present?
      @recordings = @recordings.where(user_id: params[:caller_id])
    end
    
    # Pagination
    @recordings = @recordings.page(params[:page]).per(20)
  end
  
  def show
    # Show recording details
  end
  
  def download
    if @recording.audio_file.attached?
      redirect_to rails_blob_url(@recording.audio_file), disposition: "attachment"
    else
      redirect_to recordings_path, alert: "Recording file not found"
    end
  end

  def transcript
    if @recording.transcribed?
      transcript_data = begin
        if @recording.transcription.is_a?(String)
          ruby_array = eval(@recording.transcription)
          JSON.parse(ruby_array.to_json)
        else
          @recording.transcription
        end
      end

      render json: transcript_data
    else
      render json: { error: 'Transcript not available' }, status: :not_found
    end
  end

  private
  
  def require_admin
    unless current_user&.admin?
      redirect_to dashboard_path, alert: "Access denied. Admin only area."
    end
  end

  def set_recording
    @recording = Recording.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Recording not found' }, status: :not_found
  end
end 