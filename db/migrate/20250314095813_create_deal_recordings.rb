class CreateDealRecordings < ActiveRecord::Migration[7.1]
  def change
    create_table :deal_recordings do |t|
      t.references :deal, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :deal_stage, null: false, foreign_key: true
      t.text :notes

      t.timestamps
    end
  end
end
