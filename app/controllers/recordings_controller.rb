require 'json'

class RecordingsController < ApplicationController
  before_action :require_login
  before_action :set_recording, only: [:transcript]

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

  def set_recording
    @recording = Recording.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Recording not found' }, status: :not_found
  end
end 