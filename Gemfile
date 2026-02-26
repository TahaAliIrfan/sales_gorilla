source "https://rubygems.org"

ruby "3.3.0"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.1.5", ">= 7.1.5.1"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# gem 'passenger'

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Redis adapter to run Action Cable in production
gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Charts and data visualization
gem "chartkick", "~> 5.0"

# Twilio for browser-based calling
gem "twilio-ruby", "~> 7.8"

# HTTP client for Ruby
gem "httparty", "~> 0.21.0"

# CORS support for Rails API
gem 'rack-cors'

# Tailwind CSS for styling
gem "tailwindcss-rails"

# Authentication
gem 'omniauth-google-oauth2'
gem 'omniauth'
gem 'omniauth-rails_csrf_protection'
gem 'aws-sdk-s3'

# Google API client for Calendar and Gmail integration
gem 'google-api-client', '~> 0.53.0', require: ['google/apis/gmail_v1', 'google/apis/calendar_v3']

# Authorization
gem 'pundit'

# JWT Authentication
gem 'jwt'

# Time-based grouping for ActiveRecord
gem 'groupdate', "~> 6.4"

# Pagination
gem 'kaminari'

# Background job processing
gem "sidekiq", "~> 7.2"
gem "sidekiq-scheduler", "~> 5.0"

# Mail gem for email processing
gem 'mail'

# Phone number parsing and geographic location detection
gem 'phonelib'

# Timezone detection and conversion
gem 'timezone'

# PDF generation
gem 'prawn'
gem 'prawn-table'
gem 'prawn-svg'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"

  gem 'capistrano', '~> 3.17'
  gem 'capistrano-rails', '~> 1.6'
  gem 'capistrano-passenger', '~> 0.2.1'
  gem 'capistrano-rbenv', '~> 2.2'
end
