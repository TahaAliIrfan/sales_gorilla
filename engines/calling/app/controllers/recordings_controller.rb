require "json"

class RecordingsController < ApplicationController
  before_action :require_login
  layout "tenant"
  before_action :set_recording, only: [ :show, :transcript, :download ]

  after_action :verify_authorized, except: [ :index, :my_recordings ]
  after_action :verify_policy_scoped, only: [ :index, :my_recordings ]

  def index
    @recordings = policy_scope(Recording).includes(:customer, :user).recent

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
      # Allow filtering by caller_id if user is admin or if the caller_id is the current user's id
      if current_user.admin? || params[:caller_id].to_i == current_user.id
        @recordings = @recordings.where(user_id: params[:caller_id])
      end
    end

    # Pagination
    @recordings = @recordings.page(params[:page]).per(20)
  end

  def my_recordings
    @recordings = policy_scope(Recording).where(user_id: current_user.id).includes(:customer, :user).recent

    # Apply date filters if provided
    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date]).beginning_of_day
      end_date = Date.parse(params[:end_date]).end_of_day
      @recordings = @recordings.where(date: start_date..end_date)
    end

    if params[:customer_id].present?
      @recordings = @recordings.where(customer_id: params[:customer_id])
    end

    # Pagination
    @recordings = @recordings.page(params[:page]).per(20)

    render :index
  end

  def show
    authorize @recording
    @latest_analysis = @recording.latest_ai_analysis
    @analyses = @recording.ai_analyses.order(created_at: :desc)
  end

  def download
    authorize @recording
    if @recording.audio_file.attached?
      redirect_to rails_blob_url(@recording.audio_file), disposition: "attachment"
    else
      redirect_to recordings_path, alert: "Recording file not found"
    end
  end

  def transcript
    authorize @recording
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
      render json: { error: "Transcript not available" }, status: :not_found
    end
  end

  private

  def set_recording
    @recording = Recording.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Recording not found" }, status: :not_found
  end
end
