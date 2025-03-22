class AddFollowUpFieldsToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :followup_date, :datetime
    add_column :customers, :followup_notes, :text
    add_column :customers, :google_calendar_event_id, :string
    add_column :customers, :google_calendar_event_link, :string
  end
end
