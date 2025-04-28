# config valid for current version and patch releases of Capistrano
lock "~> 3.19.2"

set :application, "crm"
set :repo_url, "git@github.com:tahairfan13/crm.git"
set :user,            'ubuntu'
set :puma_threads,    [4, 16]
set :puma_workers,    0
set :branch,          'beta_implement_authorisation'
set :passenger_restart_with_touch, true
# Don't change these unless you know what you're doing
set :pty,             true
set :use_sudo,        false
set :deploy_via,      :remote_cache
set :deploy_to,       "/home/#{fetch(:user)}/#{fetch(:application)}"
set :puma_bind,       "unix:///home/#{fetch(:user)}/#{fetch(:application)}/shared/tmp/sockets/#{fetch(:application)}-puma.sock"
set :puma_state,      "/home/#{fetch(:user)}/#{fetch(:application)}/shared/tmp/pids/puma.state"
set :puma_pid,        "/home/#{fetch(:user)}/#{fetch(:application)}/shared/tmp/pids/puma.pid"
set :puma_access_log, "/home/#{fetch(:user)}/#{fetch(:application)}/shared/log/puma.error.log"
set :puma_error_log,  "/home/#{fetch(:user)}/#{fetch(:application)}/shared/log/puma.access.log"
set :ssh_options,     { forward_agent: true, user: fetch(:user), keys: %w(~/.ssh/id_rsa.pub) }
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, true  # Change to true if using ActiveRecord
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets')
append :linked_files, "config/master.key"
append :linked_files, "config/database.yml"
# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, "/var/www/my_app_name"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# append :linked_files, "config/database.yml", 'config/master.key'

# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "vendor", "storage"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
set :keep_releases, 5

# Sidekiq Configuration
set :sidekiq_config, "config/sidekiq.yml"
set :sidekiq_roles, :app
set :sidekiq_default_hooks, true
set :sidekiq_pid, File.join(shared_path, 'tmp', 'pids', 'sidekiq.pid')
set :sidekiq_env, fetch(:rack_env, fetch(:rails_env, fetch(:stage)))
set :sidekiq_log, File.join(shared_path, 'log', 'sidekiq.log')
set :sidekiq_timeout, 60
set :sidekiq_processes, 1

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure
