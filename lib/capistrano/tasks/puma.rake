# Puma is managed by systemd (see lib/capistrano/tasks/systemd.rake and
# config/systemd/puma.service). systemd:restart is invoked from the
# deploy:published hook there, so we don't need a separate puma task here.
