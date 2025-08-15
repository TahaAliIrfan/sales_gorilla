Rails.application.routes.draw do
  get 'manager/dashboard', to: 'manager#dashboard', as: 'manager_dashboard'
  get 'manager/team_hierarchy', to: 'manager#team_hierarchy', as: 'team_hierarchy'
  get 'users/index'
  get 'users/show'
  get 'users/associates'
  get 'users/managers'
  # Remove auto-generated routes
  # get 'role_assignments/create'
  # get 'role_assignments/destroy'
  # get 'roles/index'
  # get 'roles/new'
  # get 'roles/create'
  # get 'roles/edit'
  # get 'roles/update'
  # get 'roles/destroy'
  
  # Add proper resources for roles and role assignments
  resources :roles
  resources :role_assignments, only: [:create, :destroy]
  
  # Add a route for user management with role assignment
  resources :users, only: [:index, :show] do
    member do
      post :assign_role
      delete :remove_role
      get :manage_associates
      post :assign_associate
      delete :remove_associate
    end
    
    collection do
      get :associates
      get :managers
    end
  end
  
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
      post 'analyze_phone'
      post 'ai_call'
    end
    
    # Add routes for follow-ups
    resources :followups, controller: 'customer_followups', only: [:new, :create]
    
    # Add routes for emails
    resources :emails do
      collection do
        get 'fetch'
      end
      member do
        post 'mark_as_read'
      end
    end
    
    collection do
      post 'bulk_assign'
      post 'bulk_status_change'
    end
  end
  resources :pipelines do
    member do
      patch 'assign_users'
    end
    resources :deal_stages, except: [:index]
  end
  resources :deal_stages, only: [:index]
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
  
  # Notification routes
  resources :notifications, only: [:index, :show] do
    member do
      post 'mark_as_read'
    end
    collection do
      post 'mark_all_as_read'
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
      
      # WhatsApp routes (no authentication required)
      resources :whatsapp, only: [:index] do
        collection do
          get 'customer/:customer_id/messages', to: 'whatsapp#show_customer_messages', as: :customer_messages
          post 'customer/:customer_id/send_text', to: 'whatsapp#send_text_message', as: :send_text
          post 'customer/:customer_id/send_image', to: 'whatsapp#send_image_message', as: :send_image
          post 'customer/:customer_id/sync', to: 'whatsapp#sync_messages', as: :sync_messages
        end
      end
    end
    
    namespace :v2 do
      # Authentication routes
      post 'auth/login', to: 'authentication#login'
      post 'auth/google_sign_in', to: 'authentication#google_sign_in'
      delete 'auth/logout', to: 'authentication#logout'
      get 'auth/profile', to: 'authentication#profile'
      
      # Resource routes
      resources :customers do
        member do
          patch 'update_status'
          patch 'update_communication_status' 
          get 'whatsapp_messages'
          post 'send_whatsapp_text'
          post 'send_whatsapp_media'
          post 'analyze_phone'
          get 'recordings'
        end
        collection do
          post 'bulk_assign'
          post 'bulk_status_change'
        end
      end
      
      resources :deals do
        collection do
          get 'my_deals'
        end
        member do
          patch 'update_stage'
          patch 'mark_as_won'
          patch 'mark_as_lost'
          patch 'assign_user'
        end
      end
      
      resources :tasks do
        member do
          patch 'mark_as_completed'
          patch 'mark_as_pending'
        end
      end
      
      resources :users do
        member do
          patch 'update_fcm_token'
        end
      end
      resources :recordings
      resources :pipelines
      resources :deal_stages
      resources :notifications
      resources :emails
      
      # WhatsApp routes
      resources :whatsapp, only: [:index] do
        collection do
          get 'customer/:customer_id/messages', to: 'whatsapp#show_customer_messages', as: :customer_messages
          post 'customer/:customer_id/send_text', to: 'whatsapp#send_text_message', as: :send_text
          post 'customer/:customer_id/send_image', to: 'whatsapp#send_image_message', as: :send_image
          post 'customer/:customer_id/sync', to: 'whatsapp#sync_messages', as: :sync_messages
        end
      end
      
      # Twilio routes
      get 'twilio/token', to: 'twilio#token'
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

  # WhatsApp Chat routes (authenticated)
  get 'whatsapp_chat', to: 'chats#index', as: :whatsapp_chat
  
  # Chat routes
  resources :chats, only: [:index, :show] do
    member do
      post 'send_message'
      post 'send_media'
      post 'mark_as_seen'
    end
    collection do
      get 'get_chat_id'
    end
  end
  
  # Webhook routes
  post '/chats/messaged_recieve', to: 'webhooks#message_received'
  
  # Development login gateway (only available in development)
  if Rails.env.development?
    get '/dev_login', to: 'dev_login#show', as: :dev_login
    post '/dev_login', to: 'dev_login#create'
  end
end
