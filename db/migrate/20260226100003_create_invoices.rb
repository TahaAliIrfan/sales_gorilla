class CreateInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :invoices do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :milestone, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :invoice_number, null: false
      t.string :project_name
      t.text :description
      t.date :issue_date, null: false
      t.date :due_date, null: false
      t.decimal :tax_rate, precision: 5, scale: 2, default: 0
      t.decimal :tax_amount, precision: 12, scale: 2, default: 0
      t.decimal :total, precision: 12, scale: 2, null: false

      t.timestamps
    end

    add_index :invoices, :invoice_number, unique: true
    add_index :invoices, :issue_date
  end
end
