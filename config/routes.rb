Rails.application.routes.draw do
  # Sidekiq Web UI
  require 'sidekiq/web'
  
  # Secure the Sidekiq UI with admin-only access
  authenticate = lambda do |request|
    user_id = request.session[:user_id]
    user = User.find_by(id: user_id)
    user&.admin?
  end
  
  constraints authenticate do
    mount Sidekiq::Web => '/sidekiq'
  end

  get 'tasks/index'
  get 'tasks/show'
  get 'tasks/new'
  get 'tasks/edit'
  get 'tasks/create'
  get 'tasks/update'
  get 'tasks/destroy'
  get 'tasks/complete'
  get 'settings/edit'
  get 'settings/update'
  
  # Add RESTful routes for our models
  resources :customers do
    member do
      patch 'update_status'
      patch 'update_communication_status'
      get 'whatsapp_messages'
      post 'send_whatsapp_text'
      post 'send_whatsapp_media'
    end
    
    # Add routes for follow-ups
    resources :followups, controller: 'customer_followups', only: [:new, :create]
    
    collection do
      post 'bulk_assign'
    end
  end
  resources :deal_stages
  resources :tasks do
    member do
      patch 'complete'
    end
    collection do
      get 'my_tasks'
    end
  end
  resources :deals do
    collection do
      get 'my_deals', to: 'deals#my_deals'
    end
    member do
      patch 'update_stage'
      patch 'mark_as_won'
      patch 'mark_as_lost'
      patch 'assign_user'
    end
  end
  
  # Root path route ("/")
  root "home#index"

  # Authentication routes
  get '/auth/:provider/callback', to: 'sessions#create'
  get '/auth/failure', to: 'sessions#failure'
  get '/signout', to: 'sessions#destroy', as: :signout
  get '/signin', to: 'sessions#new', as: :signin
  get '/auth/google_oauth2', to: 'sessions#new', as: :google_oauth2

  # Dashboard routes
  get 'dashboard', to: 'dashboard#index', as: :admin_dashboard
  get 'dashboard/reports', to: 'dashboard#reports', as: :reports
  get 'dashboard/my_reports', to: 'dashboard#my_reports', as: :my_reports
  
  # User Dashboard routes
  get 'my_dashboard', to: 'user_dashboard#index', as: :dashboard
  
  # My Tasks Dashboard route
  get 'my_tasks_dashboard', to: 'my_tasks_dashboard#index', as: :my_tasks_dashboard
  
  # Settings routes
  get 'settings', to: 'settings#edit', as: :settings
  patch 'settings/update', to: 'settings#update', as: :update_settings
  delete 'settings/disconnect_google', to: 'settings#disconnect_google', as: :disconnect_google
  
  # Browser-based calling routes
  get 'calling', to: 'calling#index'
  get 'calling/token', to: 'calling#token'
  match 'calling/voice', to: 'calling#voice', via: [:get, :post]
  get 'calling/available_numbers', to: 'calling#available_numbers'
  post 'calling/store_customer_id', to: 'calling#store_customer_id'
  
  # Call recording routes
  get 'calling/recordings', to: 'calling#recordings'
  get 'calling/recording/:sid', to: 'calling#recording', as: :get_recording
  get 'calling/play_recording/:sid', to: 'calling#play_recording', as: :calling_play_recording
  post 'calling/recording_status', to: 'calling#recording_status'
  
  # API routes
  namespace :api do
    namespace :v1 do
      post 'cost_calculator', to: 'cost_calculator#cost_calculator'
      post 'inbound_lead', to: 'cost_calculator#inbound_lead'
    end
  end
  
  # Test routes
  get 'test/cost_calculator', to: redirect('/test_cost_calculator_api.html')

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  resources :recordings, only: [:index, :show] do
    member do
      get :transcript
      get :download
    end
    collection do
      get :my_recordings
    end
    
    resources :ai_analyses, only: [:create, :show]
  end

  # Chat routes
  resources :chats, only: [:index] do
    collection do
      get 'get_chat_id'
    end
  end
end
