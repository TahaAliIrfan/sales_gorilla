class AddMetaCapiWebsiteFieldsToCustomers < ActiveRecord::Migration[7.1]
  def change
    # Fields captured for Meta Conversions API "website" Lead events to maximize
    # match quality. client_ip_address / client_user_agent are sent un-hashed and
    # only on browser-sourced (action_source: "website") events. event_source_url
    # is the page URL the form was submitted from. zip rounds out the address
    # identifiers (ct/st/zp/country) Meta hashes for matching.
    add_column :customers, :client_ip_address, :string
    add_column :customers, :client_user_agent, :text
    add_column :customers, :event_source_url, :text
    add_column :customers, :zip, :string
  end
end
