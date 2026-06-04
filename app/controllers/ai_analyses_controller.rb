class AiAnalysesController < ApplicationController
  layout 'dashboard'
  before_action :set_recording
  
  def create
    if !@recording.transcribed?
      redirect_to recording_path(@recording), alert: "Cannot analyze recording without a transcript"
      return
    end
    
    service = DeepSeekRecordingService.new
    analysis = service.analyze_recording(@recording)
    
    if analysis
      redirect_to recording_path(@recording), notice: "AI analysis completed successfully"
    else
      redirect_to recording_path(@recording), alert: "Failed to complete AI analysis"
    end
  end
  
  def show
    authorize @recording, :show?
    @analysis = @recording.ai_analyses.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to recording_path(@recording), alert: "Analysis not found"
  end
  
  private
  
  def set_recording
    @recording = Recording.find(params[:recording_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to recordings_path, alert: "Recording not found"
  end
end 