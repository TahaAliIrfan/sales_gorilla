class AddFieldsToCalls < ActiveRecord::Migration[7.1]
  def change
    add_column :calls, :call_type, :string, default: 'outbound'
  end
end
