class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Universal method to fetch and store WhatsApp messages
  def self.fetch_whatsapp_messages(whatsapp_chat_id, customer = nil)
    WhatsappMessageService.new.fetch_and_store_messages(whatsapp_chat_id, customer)
  end
end
