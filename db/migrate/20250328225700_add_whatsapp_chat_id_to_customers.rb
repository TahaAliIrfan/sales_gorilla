class AddWhatsappChatIdToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :whatsapp_chat_id, :string
  end
end
