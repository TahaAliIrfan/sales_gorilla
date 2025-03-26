# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

# Tecaudex CRM

This is a CRM application for managing customers, deals, and tasks.

## System Requirements

* Ruby 3.3.0
* Rails 7.1.5
* PostgreSQL
* Redis (for Sidekiq)

## Setup and Installation

1. Clone the repository
2. Run `bundle install` to install gems
3. Configure database in `config/database.yml`
4. Run `rails db:create db:migrate` to set up the database
5. Start the development server with `bin/dev` to run Rails, CSS compilation, and Sidekiq

## Background Processing with Sidekiq

This application uses Sidekiq for processing background jobs:

* Customer follow-ups with Google Calendar integration
* Email notifications
* Task reminders

### Starting Sidekiq in Development

Sidekiq is automatically started when you run the application with `bin/dev` (using Procfile.dev).

You can also run Sidekiq manually with:

```bash
bundle exec sidekiq -C config/sidekiq.yml
```

### Accessing Sidekiq Dashboard

The Sidekiq web dashboard is available at `/sidekiq` (admin-only access).

### Scheduled Jobs

The application uses sidekiq-scheduler for recurring tasks:

* Daily task reminders (7:00 AM)

Configure scheduled jobs in `config/sidekiq_scheduler.yml`

## Deployment

The application is configured to deploy using Capistrano with support for Sidekiq.
