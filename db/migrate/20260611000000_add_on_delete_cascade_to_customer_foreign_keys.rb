class AddOnDeleteCascadeToCustomerForeignKeys < ActiveRecord::Migration[7.1]
  # Tables that reference customers via a FK but have no Customer model
  # association carrying `dependent:`, so deleting a Customer raised
  # PG::ForeignKeyViolation. Cascade the delete at the DB level instead.
  TABLES = %w[calls eleven_labs_calls ndas notification_logs sms odoo_proposals].freeze

  def up
    TABLES.each do |table|
      next unless table_exists?(table) && foreign_key_exists?(table, :customers)

      remove_foreign_key table, :customers
      add_foreign_key table, :customers, on_delete: :cascade
    end
  end

  def down
    TABLES.each do |table|
      next unless table_exists?(table) && foreign_key_exists?(table, :customers)

      remove_foreign_key table, :customers
      add_foreign_key table, :customers
    end
  end
end
