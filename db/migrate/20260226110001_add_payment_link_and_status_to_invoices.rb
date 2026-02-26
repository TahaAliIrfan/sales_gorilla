class AddPaymentLinkAndStatusToInvoices < ActiveRecord::Migration[7.1]
  def change
    add_column :invoices, :payment_link, :string
    add_column :invoices, :status, :string, default: 'pending', null: false
    add_index :invoices, :status
  end
end
