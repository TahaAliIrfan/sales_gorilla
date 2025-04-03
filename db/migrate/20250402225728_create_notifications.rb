class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.text :content
      t.boolean :read, default: false
      t.string :notification_type
      t.references :resource, polymorphic: true, index: true

      t.timestamps
    end
    
    add_index :notifications, [:user_id, :read]
    add_index :notifications, :created_at
  end
end
