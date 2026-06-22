require "sidekiq/testing"

# Default to real-client behavior (same as before this file existed) so no
# existing spec is affected. Specs that need to assert on enqueued jobs opt in
# with `:sidekiq_fake` metadata, which enables fake mode + a clean queue for
# just that example.
Sidekiq::Testing.disable!

RSpec.configure do |config|
  config.around(:each, :sidekiq_fake) do |example|
    Sidekiq::Testing.fake! do
      Sidekiq::Worker.clear_all
      example.run
    end
  end
end
