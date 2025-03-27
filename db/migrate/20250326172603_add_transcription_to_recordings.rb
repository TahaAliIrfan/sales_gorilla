class AddTranscriptionToRecordings < ActiveRecord::Migration[7.1]
  def change
    add_column :recordings, :transcription, :jsonb
    add_column :recordings, :transcription_status, :string
  end
end
