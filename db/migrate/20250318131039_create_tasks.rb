class CreateTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :tasks do |t|
      t.string :title
      t.text :description
      t.datetime :due_date
      t.string :status, default: 'Pending'
      t.references :user, null: false, foreign_key: true
      t.references :customer, null: true, foreign_key: true
      t.string :priority, default: 'Medium'
      t.boolean :completed, default: false

      t.timestamps
    end
    
    add_index :tasks, :status
    add_index :tasks, :due_date
    add_index :tasks, :completed
  end
end
