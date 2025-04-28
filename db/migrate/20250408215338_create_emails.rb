class CreateEmails < ActiveRecord::Migration[7.1]
  def change
    create_table :emails do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :message_id
      t.string :gmail_thread_id
      t.string :subject
      t.text :body_html
      t.text :body_text
      t.string :from_email
      t.string :from_name
      t.string :to_email
      t.string :to_name
      t.string :status
      t.datetime :sent_at
      t.datetime :received_at
      t.datetime :read_at
      t.boolean :has_attachments

      t.timestamps
    end
    add_index :emails, :message_id
  end
end
