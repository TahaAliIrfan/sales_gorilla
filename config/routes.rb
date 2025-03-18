Rails.application.routes.draw do
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
  # Remove auto-generated routes
  # get 'deal_stages/index'
  # get 'deal_stages/new'
  # get 'deal_stages/create'
  # get 'deal_stages/edit'
  # get 'deal_stages/update'
  # get 'deal_stages/destroy'
  # get 'deals/index'
  # get 'deals/show'
  # get 'deals/new'
  # get 'deals/create'
  # get 'deals/edit'
  # get 'deals/update'
  # get 'deals/destroy'
  # get 'customers/index'
  # get 'customers/show'
  # get 'customers/new'
  # get 'customers/create'
  # get 'customers/edit'
  # get 'customers/update'
  # get 'customers/destroy'
  
  # Add RESTful routes for our models
  resources :customers
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
  get 'dashboard/reports', to: 'dashboard#reports', as: :reports_dashboard
  
  # User Dashboard routes
  get 'my_dashboard', to: 'user_dashboard#index', as: :dashboard
  
  # Settings routes
  get 'settings', to: 'settings#edit', as: :settings
  patch 'settings/update', to: 'settings#update', as: :update_settings
  
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
    end
  end
  
  # Test routes
  get 'test/cost_calculator', to: redirect('/test_cost_calculator_api.html')

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
