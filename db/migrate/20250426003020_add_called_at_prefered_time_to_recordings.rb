class AddCalledAtPreferedTimeToRecordings < ActiveRecord::Migration[7.1]
  def change
    add_column :recordings, :called_at_prefered_time, :boolean, default: false, null: false
    add_index :recordings, :called_at_prefered_time
  end
end
