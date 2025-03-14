class CreateRecordings < ActiveRecord::Migration[7.1]
  def change
    create_table :recordings do |t|
      t.string :sid
      t.integer :duration
      t.datetime :date
      t.string :url
      t.string :call_sid
      t.references :user, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true

      t.timestamps
    end
  end
end
