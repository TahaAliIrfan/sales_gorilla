class CreateCampaignGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :campaign_groups do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :customer_group, null: false, foreign_key: true

      t.timestamps
    end
  end
end
