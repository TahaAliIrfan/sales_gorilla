class AddRolesTable < ActiveRecord::Migration[7.1]
  def change
    # Update the existing roles table
    change_table :roles do |t|
      # Add key column if it doesn't exist
      unless column_exists?(:roles, :key)
        add_column :roles, :key, :string, null: false
        add_index :roles, :key, unique: true
      end

      # Add hierarchy_level column if it doesn't exist
      unless column_exists?(:roles, :hierarchy_level)
        add_column :roles, :hierarchy_level, :integer, default: 0
        add_index :roles, :hierarchy_level
      end

      # Make name not null
      change_column_null :roles, :name, false

      # Remove permissions column if it exists
      if column_exists?(:roles, :permissions)
        remove_column :roles, :permissions
      end
    end
  end
end
