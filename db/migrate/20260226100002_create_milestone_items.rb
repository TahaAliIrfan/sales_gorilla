class CreateMilestoneItems < ActiveRecord::Migration[7.1]
  def change
    create_table :milestone_items do |t|
      t.references :milestone, null: false, foreign_key: true
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :due_date
      t.string :description, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :milestone_items, :position
  end
end
