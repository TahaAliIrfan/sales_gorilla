class AddRecordingSidToDealRecordings < ActiveRecord::Migration[7.1]
  def change
    add_column :deal_recordings, :recording_sid, :string
  end
end
