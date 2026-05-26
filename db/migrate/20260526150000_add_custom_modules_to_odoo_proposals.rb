class AddCustomModulesToOdooProposals < ActiveRecord::Migration[7.1]
  def change
    add_column :odoo_proposals, :custom_modules, :jsonb, default: []
  end
end
