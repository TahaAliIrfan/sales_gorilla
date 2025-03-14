class DropCallsTable < ActiveRecord::Migration[7.1]
  def up
    drop_table :calls
  end

  def down
    create_table :calls do |t|
      t.string :phone_number
      t.string :recording_sid
      t.string :call_type, default: 'outbound'

      t.timestamps
    end
  end
end
