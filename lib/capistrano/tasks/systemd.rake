namespace :systemd do
  desc "Install systemd unit files for puma and sidekiq"
  task :setup do
    on roles(:app) do
      %w[puma sidekiq].each do |svc|
        upload! StringIO.new(File.read("config/systemd/#{svc}.service")), "/tmp/#{svc}.service"
        sudo :mv, "/tmp/#{svc}.service", "/etc/systemd/system/#{svc}.service"
      end
      sudo :systemctl, "daemon-reload"
      sudo :systemctl, "enable", "puma", "sidekiq"
    end
  end

  desc "Start puma and sidekiq"
  task :start do
    on roles(:app) do
      sudo :systemctl, "start", "puma", "sidekiq"
    end
  end

  desc "Stop puma and sidekiq"
  task :stop do
    on roles(:app) do
      sudo :systemctl, "stop", "puma", "sidekiq"
    end
  end

  desc "Restart puma and sidekiq"
  task :restart do
    on roles(:app) do
      sudo :systemctl, "restart", "puma", "sidekiq"
    end
  end

  desc "Status of puma and sidekiq"
  task :status do
    on roles(:app) do
      execute :sudo, :systemctl, "status", "puma", "--no-pager"
      execute :sudo, :systemctl, "status", "sidekiq", "--no-pager"
    end
  end
end

after "deploy:published", "systemd:setup"
after "systemd:setup", "systemd:restart"
