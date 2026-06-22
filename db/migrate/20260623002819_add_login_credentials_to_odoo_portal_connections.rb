class AddLoginCredentialsToOdooPortalConnections < ActiveRecord::Migration[7.1]
  def change
    add_column :odoo_portal_connections, :login_email, :string
    add_column :odoo_portal_connections, :login_password, :text  # encrypted
  end
end
