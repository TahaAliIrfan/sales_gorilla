class CreateDealStages < ActiveRecord::Migration[7.1]
  def change
    create_table :deal_stages do |t|
      t.string :name
      t.integer :position
      t.text :description

      t.timestamps
    end
  end
end
