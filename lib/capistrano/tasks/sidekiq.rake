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
        execute :bundle, :exec, :sidekiq,
          "-e #{fetch(:rails_env)} -C #{current_path}/config/sidekiq.yml -P #{shared_path}/tmp/pids/sidekiq.pid -L #{shared_path}/log/sidekiq.log &"
      end
    end
  end

  task :restart do
    invoke 'sidekiq:stop'
    invoke 'sidekiq:start'
  end
end

after 'deploy:starting', 'sidekiq:quiet'
after 'deploy:published', 'sidekiq:restart' 