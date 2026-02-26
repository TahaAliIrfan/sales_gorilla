class CreateMilestones < ActiveRecord::Migration[7.1]
  def change
    create_table :milestones do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :total_amount, precision: 12, scale: 2, null: false
      t.string :schedule_type, default: 'milestone', null: false
      t.string :status, default: 'unpaid', null: false
      t.datetime :paid_at
      t.string :currency, default: 'USD'
      t.text :notes

      t.timestamps
    end

    add_index :milestones, :status
    add_index :milestones, :schedule_type
  end
end
