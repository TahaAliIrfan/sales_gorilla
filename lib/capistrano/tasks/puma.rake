namespace :puma do
  desc "Restart Puma"
  task :restart do
    on roles(:app) do
      sudo :systemctl, "restart", "puma"
      info "Puma restarted successfully"
    end
  end

  desc "Start Puma"
  task :start do
    on roles(:app) do
      sudo :systemctl, "start", "puma"
      info "Puma started successfully"
    end
  end

  desc "Stop Puma"
  task :stop do
    on roles(:app) do
      sudo :systemctl, "stop", "puma"
      info "Puma stopped successfully"
    end
  end

  desc "Check Puma status"
  task :status do
    on roles(:app) do
      execute :sudo, :systemctl, "status", "puma", "--no-pager"
    end
  end
end

# Hook into Capistrano's deployment process
# Restart Puma after publishing the new release
after "deploy:published", "puma:restart"
