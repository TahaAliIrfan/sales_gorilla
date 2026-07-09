class MigrateInvoicePaymentLinksData < ActiveRecord::Migration[7.1]
  def up
    # Move the single legacy payment_link/payment_link_label into the new
    # invoice_payment_links table so nothing is lost, then drop the columns.
    execute <<~SQL
      INSERT INTO invoice_payment_links (invoice_id, label, url, position, created_at, updated_at)
      SELECT id,
             COALESCE(NULLIF(payment_link_label, ''), 'Pay online'),
             payment_link,
             0,
             NOW(),
             NOW()
      FROM invoices
      WHERE payment_link IS NOT NULL AND payment_link <> ''
    SQL

    remove_column :invoices, :payment_link
    remove_column :invoices, :payment_link_label
  end

  def down
    add_column :invoices, :payment_link, :string
    add_column :invoices, :payment_link_label, :string
  end
end
