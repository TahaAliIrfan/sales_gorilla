class CreateEmailAttachments < ActiveRecord::Migration[7.1]
  def change
    create_table :email_attachments do |t|
      t.references :email, null: false, foreign_key: true
      t.string :filename
      t.string :content_type
      t.string :attachment_id
      t.integer :size

      t.timestamps
    end
  end
end
