class CreateAdminAssistantMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_assistant_messages do |t|
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false

      t.timestamps
    end

    add_index :admin_assistant_messages, [:user_id, :created_at]
  end
end
