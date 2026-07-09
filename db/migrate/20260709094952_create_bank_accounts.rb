class CreateBankAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :bank_accounts do |t|
      t.string :label, null: false
      t.string :country
      t.string :currency
      t.string :bank_name
      t.text :bank_address
      t.string :beneficiary_name
      t.string :account_number
      t.string :sort_code
      t.string :routing_number
      t.string :bsb
      t.string :iban
      t.string :swift_bic
      t.text :additional_info
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
