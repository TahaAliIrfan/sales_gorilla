namespace :systemd do
  desc "Setup systemd services"
  task :setup do
    on roles(:app) do
      # Copy the Sidekiq service file to the server
      upload! StringIO.new(File.read("config/systemd/sidekiq.service")), "/tmp/sidekiq.service"
      sudo :mv, "/tmp/sidekiq.service", "/etc/systemd/system/sidekiq.service"

      # Reload systemd
      sudo :systemctl, "daemon-reload"

      # Enable the Sidekiq service to start at boot
      sudo :systemctl, "enable", "sidekiq"
    end
  end

  desc "Start systemd services"
  task :start do
    on roles(:app) do
      sudo :systemctl, "start", "sidekiq"
    end
  end

  desc "Stop systemd services"
  task :stop do
    on roles(:app) do
      sudo :systemctl, "stop", "sidekiq"
    end
  end

  desc "Restart systemd services"
  task :restart do
    on roles(:app) do
      sudo :systemctl, "restart", "sidekiq"
    end
  end

  desc "Check status of systemd services"
  task :status do
    on roles(:app) do
      puts capture("sudo systemctl status sidekiq")
    end
  end
end

# Add hooks to deploy process
after "deploy:published", "systemd:setup"
after "systemd:setup", "systemd:restart"
