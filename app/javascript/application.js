// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "sortable_setup"
import "chartkick"
import "Chart.js"

// Start Active Storage
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
