class CreateDeals < ActiveRecord::Migration[7.1]
  def change
    create_table :deals do |t|
      t.string :title
      t.text :description
      t.decimal :amount
      t.references :customer, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :deal_stage, null: false, foreign_key: true
      t.date :expected_close_date
      t.string :status

      t.timestamps
    end
  end
end
