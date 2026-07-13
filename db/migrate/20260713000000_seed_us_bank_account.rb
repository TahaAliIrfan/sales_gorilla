class SeedUsBankAccount < ActiveRecord::Migration[7.1]
  # Idempotent seed of the US (Citibank) bank account so it exists in every
  # environment on deploy (deploy runs migrations, not db:seed). Uses raw SQL
  # to avoid coupling to the model. Mirrors db/seeds.rb for fresh setups.
  def up
    existing = select_value("SELECT COUNT(*) FROM bank_accounts WHERE label = 'United States (USD)'").to_i
    return if existing.positive?

    execute <<~SQL
      INSERT INTO bank_accounts
        (label, country, currency, bank_name, bank_address, beneficiary_name,
         account_number, routing_number, swift_bic, additional_info,
         active, position, created_at, updated_at)
      VALUES
        ('United States (USD)', 'United States', 'USD', 'Citibank',
         '111 Wall Street New York, NY 10043 USA', 'Tecaudex Private Limited',
         '70583220000970144', '031100209', 'CITIUS33', 'Account type: CHECKING',
         TRUE, 2, NOW(), NOW())
    SQL
  end

  def down
    execute "DELETE FROM bank_accounts WHERE label = 'United States (USD)'"
  end
end
