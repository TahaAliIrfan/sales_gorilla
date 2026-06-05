class AddOpenTrackingToEmails < ActiveRecord::Migration[7.1]
  def change
    change_table :emails do |t|
      # Random, opaque token used as the URL component for the tracking pixel
      # (`/e/o/:token.gif`). Generated when an outbound email is sent. Indexed
      # because the pixel endpoint looks emails up by it on every render.
      t.string :tracking_token

      # First and last open events. `first_opened_at` stays sticky after the
      # initial pixel hit; `last_opened_at` updates on every subsequent hit.
      # `open_count` is incremented atomically.
      t.datetime :first_opened_at
      t.datetime :last_opened_at
      t.integer  :open_count, null: false, default: 0
    end

    add_index :emails, :tracking_token, unique: true, where: "tracking_token IS NOT NULL"
  end
end
