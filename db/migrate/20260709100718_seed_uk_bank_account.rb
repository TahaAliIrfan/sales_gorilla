class SeedUkBankAccount < ActiveRecord::Migration[7.1]
  # Idempotent seed of the UK (Barclays) bank account so it exists in every
  # environment on deploy (deploy runs migrations, not db:seed). Uses raw SQL
  # to avoid coupling to the model. Mirrors db/seeds.rb for fresh setups.
  def up
    existing = select_value("SELECT COUNT(*) FROM bank_accounts WHERE label = 'United Kingdom (GBP)'").to_i
    return if existing.positive?

    execute <<~SQL
      INSERT INTO bank_accounts
        (label, country, currency, bank_name, bank_address, beneficiary_name,
         account_number, sort_code, active, position, created_at, updated_at)
      VALUES
        ('United Kingdom (GBP)', 'United Kingdom', 'GBP', 'Barclays',
         'Level 25, 1 Churchill Place London E14 5HP', 'Tecaudex Private Limited',
         '15386296', '231486', TRUE, 1, NOW(), NOW())
    SQL
  end

  def down
    execute "DELETE FROM bank_accounts WHERE label = 'United Kingdom (GBP)'"
  end
end
