class CreateOdooProposals < ActiveRecord::Migration[7.1]
  def change
    create_table :odoo_proposals do |t|
      t.references :customer, null: true, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :customer_name
      t.string :deployment_type, null: false, default: 'online'
      t.string :hosting_tier
      t.integer :num_users, null: false, default: 5
      t.jsonb :selected_modules, null: false, default: []
      t.decimal :implementation_fee, precision: 12, scale: 2, default: 0
      t.decimal :annual_hosting_cost, precision: 12, scale: 2, default: 0
      t.text :notes
      t.string :status, default: 'draft'
      t.timestamps
    end
  end
end
