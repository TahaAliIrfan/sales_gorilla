class CreateInvoiceLineItems < ActiveRecord::Migration[7.1]
  def change
    create_table :invoice_line_items do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :milestone_item, null: true, foreign_key: true
      t.string :description, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :invoice_line_items, :position
  end
end
