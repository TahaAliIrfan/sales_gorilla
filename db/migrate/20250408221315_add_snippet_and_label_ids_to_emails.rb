class AddSnippetAndLabelIdsToEmails < ActiveRecord::Migration[7.1]
  def change
    add_column :emails, :snippet, :text
    add_column :emails, :label_ids, :string
    add_index :emails, :label_ids
  end
end
