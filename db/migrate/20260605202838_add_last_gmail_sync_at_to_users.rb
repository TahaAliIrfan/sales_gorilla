class AddLastGmailSyncAtToUsers < ActiveRecord::Migration[7.1]
  def change
    # Tracks the last successful Gmail inbox sync for this user. Used as the
    # `after:` cursor in the next sync so we don't re-walk the entire inbox.
    add_column :users, :last_gmail_sync_at, :datetime
  end
end
