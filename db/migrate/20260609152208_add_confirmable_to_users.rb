class AddConfirmableToUsers < ActiveRecord::Migration[7.1]
  def up
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string # reconfirmable (email change)
    add_index  :users, :confirmation_token, unique: true

    # Existing users predate confirmation — treat them as already confirmed so
    # nobody gets locked out when :confirmable turns on.
    execute "UPDATE users SET confirmed_at = NOW() WHERE confirmed_at IS NULL"
  end

  def down
    remove_index  :users, :confirmation_token
    remove_column :users, :confirmation_token
    remove_column :users, :confirmed_at
    remove_column :users, :confirmation_sent_at
    remove_column :users, :unconfirmed_email
  end
end
