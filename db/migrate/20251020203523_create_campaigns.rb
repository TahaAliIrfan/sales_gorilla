class CreateCampaigns < ActiveRecord::Migration[7.1]
  def change
    create_table :campaigns do |t|
      t.string :name, null: false
      t.text :message, null: false
      t.string :status, null: false, default: 'draft'
      t.datetime :scheduled_at
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :campaigns, :status
    add_index :campaigns, :scheduled_at
  end
end
