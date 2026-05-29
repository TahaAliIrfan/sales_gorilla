class CreateWhatsappTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_templates do |t|
      t.string  :content_sid,     null: false
      t.string  :friendly_name
      t.string  :language
      t.string  :category
      t.string  :approval_status
      t.text    :body
      t.jsonb   :types,     default: {}
      t.jsonb   :variables, default: {}
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :whatsapp_templates, :content_sid, unique: true
    add_index :whatsapp_templates, :approval_status
  end
end
