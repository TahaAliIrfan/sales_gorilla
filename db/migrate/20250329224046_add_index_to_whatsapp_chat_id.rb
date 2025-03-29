class AddIndexToWhatsappChatId < ActiveRecord::Migration[7.1]
  def change
    add_index :customers, :whatsapp_chat_id
  end
end
