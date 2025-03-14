class CreateCalls < ActiveRecord::Migration[7.1]
  def change
    create_table :calls do |t|
      t.string :phone_number
      t.string :recording_sid

      t.timestamps
    end
  end
end
