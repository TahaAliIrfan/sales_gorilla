class CreateDealActivities < ActiveRecord::Migration[7.1]
  def change
    create_table :deal_activities do |t|
      t.references :deal, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action
      t.text :details

      t.timestamps
    end
  end
end
