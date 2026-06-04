require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "factory_bot_rails"

# Auto-require everything under spec/support (factories, shared examples, helpers).
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!
  config.infer_spec_type_from_file_location!

  config.include FactoryBot::Syntax::Methods

  # Reset acts_as_tenant's current tenant between examples. Tests that need a
  # tenant should set it explicitly with `ActsAsTenant.with_tenant(org) { ... }`
  # or via the `:as_tenant` shared context.
  config.before(:each) { ActsAsTenant.current_tenant = nil }
  config.after(:each)  { ActsAsTenant.current_tenant = nil }
end
