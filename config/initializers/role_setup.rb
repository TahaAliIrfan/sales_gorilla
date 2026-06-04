# This initializer sets up the default roles for the application
Rails.application.config.after_initialize do
  # Only run this in non-test environments and when the roles table exists
  if !Rails.env.test? &&
     ActiveRecord::Base.connection.table_exists?("roles") &&
     ActiveRecord::Base.connection.column_exists?("roles", "key") &&
     ActiveRecord::Base.connection.column_exists?("roles", "hierarchy_level")
    # Create default roles if they don't exist
    Role.seed_default_roles

    puts "Roles have been set up successfully."
  end
end
