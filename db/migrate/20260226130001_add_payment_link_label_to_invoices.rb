# frozen_string_literal: true

class AddPaymentLinkLabelToInvoices < ActiveRecord::Migration[7.1]
  def change
    add_column :invoices, :payment_link_label, :string
  end
end
