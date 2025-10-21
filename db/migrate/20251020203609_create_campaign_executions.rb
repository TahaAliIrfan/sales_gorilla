class CreateCampaignExecutions < ActiveRecord::Migration[7.1]
  def change
    create_table :campaign_executions do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.string :status, null: false, default: 'pending'
      t.datetime :scheduled_at, null: false
      t.datetime :executed_at
      t.text :error_message

      t.timestamps
    end

    add_index :campaign_executions, :status
    add_index :campaign_executions, :scheduled_at
    add_index :campaign_executions, [:campaign_id, :customer_id], unique: true, name: 'index_campaign_executions_unique'
  end
end
