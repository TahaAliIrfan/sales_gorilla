# This file should ensure the existence of records required to run the application.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# --- Bank accounts (for invoice bank-transfer payment option) ---
# Add US and AUS accounts here (or via the console) as their details are confirmed.
BankAccount.find_or_create_by!(label: "United Kingdom (GBP)") do |ba|
  ba.country          = "United Kingdom"
  ba.currency         = "GBP"
  ba.bank_name        = "Barclays"
  ba.bank_address     = "Level 25, 1 Churchill Place London E14 5HP"
  ba.sort_code        = "231486"
  ba.account_number   = "15386296"
  ba.beneficiary_name = "Tecaudex Private Limited"
  ba.active           = true
  ba.position         = 1
end
