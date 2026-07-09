class AddBankAccountToInvoices < ActiveRecord::Migration[7.1]
  def change
    add_reference :invoices, :bank_account, null: true, foreign_key: true
  end
end
