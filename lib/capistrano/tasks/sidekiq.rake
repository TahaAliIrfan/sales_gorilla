namespace :sidekiq do
  task :quiet do
    on roles(:app) do
      puts capture("pgrep -f 'sidekiq' | xargs kill -TSTP") rescue nil
    end
  end

  task :stop do
    on roles(:app) do
      puts capture("pgrep -f 'sidekiq' | xargs kill -TERM") rescue nil
    end
  end

  task :start do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          if fetch(:rails_env) == 'production'
            execute :nohup, :bundle, :exec, :sidekiq,
              "-e production -C config/sidekiq.yml >> #{shared_path}/log/sidekiq.log 2>&1 &"
          else
            execute :nohup, :bundle, :exec, :sidekiq,
              "-e #{fetch(:rails_env)} -C config/sidekiq.yml >> #{shared_path}/log/sidekiq.log 2>&1 &"
          end
        end
      end
    end
  end

  task :restart do
    invoke 'sidekiq:stop'
    sleep 5  # Add a delay to ensure the process is fully stopped
    invoke 'sidekiq:start'
  end
end

after 'deploy:starting', 'sidekiq:quiet'
after 'deploy:published', 'sidekiq:restart' 