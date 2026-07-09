class CreateInvoicePaymentLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :invoice_payment_links do |t|
      t.references :invoice, null: false, foreign_key: true
      t.string :label, null: false
      t.string :url, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
