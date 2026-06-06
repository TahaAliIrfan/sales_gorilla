# Sidekiq is managed by systemd (see lib/capistrano/tasks/systemd.rake and
# config/systemd/sidekiq.service). The nohup-based start/stop tasks that used
# to live here are intentionally removed to avoid spawning a second, orphaned
# Sidekiq alongside the systemd-managed one on every deploy.
