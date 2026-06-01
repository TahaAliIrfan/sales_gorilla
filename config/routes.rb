Rails.application.routes.draw do
  get 'manager/dashboard', to: 'manager#dashboard', as: 'manager_dashboard'
  get 'users/index'
  get 'users/show'
  get 'users/associates'
  get 'users/managers'
  
  # User management routes
  resources :users, only: [:index, :show] do
    member do
      post :update_role
      post :toggle_active
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
  
  # CSV Import routes
  resources :csv_imports, only: [:new] do
    collection do
      post 'upload'
      get 'mapping'
      post 'import'
      delete 'cancel'
    end
  end

  # Campaign routes
  resources :customer_groups do
    member do
      post 'add_customer'
      delete 'remove_customer'
    end
  end

  resources :campaigns do
    member do
      post 'send_now'
      post 'schedule'
      post 'restart'
      post 'stop'
      post 'add_customers'
      delete 'remove_customer'
    end
  end

  match 'webhook', to: 'messages#webhook', via: [:get, :post]

  # Global Invoices index (sidebar)
  get 'invoices', to: 'all_invoices#index', as: :invoices

  # Public invoice view (masked URL for clients – view, download PDF, upload payment proof)
  get 'i/:token/pdf', to: 'public_invoices#download_pdf', as: :public_invoice_pdf
  get 'i/:token', to: 'public_invoices#show', as: :public_invoice
  post 'i/:token/payment_proof', to: 'public_invoices#upload_payment_proof', as: :public_invoice_payment_proof

  # Add RESTful routes for our models
  resources :customers do
    member do
      patch 'update_status'
      patch 'update_communication_status'
      post 'analyze_phone'
      post 'calculate_lead_score'
      post 'assign_to_self'
      post 'upload_documents'
      post 'mark_lead_quality'
    end

    resources :invoices do
      member do
        get :download_pdf
        patch :mark_paid
      end
    end
    resources :milestones do
      member do
        patch :mark_paid
        patch :mark_unpaid
      end
      resources :milestone_items, only: [:create, :update]
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
        get 'export_pdf'
        post 'send_draft'
      end
      resources :attachments, controller: 'email_attachments', only: [:show] do
        member do
          get 'download'
        end
      end
    end

    # Add routes for messages (WhatsApp)
    resources :messages, only: [:index, :create] do
      collection do
        patch 'sync'
        delete 'refresh'
      end
    end

    # Twilio-backed WhatsApp US channel (list + send + templates)
    get  'whatsapp_us', to: 'whatsapp_us#index'
    post 'whatsapp_us', to: 'whatsapp_us#create'
    get  'whatsapp_us/templates',      to: 'whatsapp_us#templates'
    post 'whatsapp_us/templates/sync', to: 'whatsapp_us#sync_templates'
    post 'whatsapp_us/send_template',  to: 'whatsapp_us#send_template'

    collection do
      post 'bulk_assign'
      post 'bulk_status_change'
      get 'export_csv'
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

  # Reports routes
  get 'reports', to: 'reports#index', as: :reports
  get 'reports/my_reports', to: 'reports#my_reports', as: :my_reports

  # User Dashboard routes
  get 'my_dashboard', to: 'user_dashboard#index', as: :dashboard

  # My Tasks Dashboard route
  get 'my_tasks_dashboard', to: 'my_tasks_dashboard#index', as: :my_tasks_dashboard

  # Settings routes
  get 'settings', to: 'settings#edit', as: :settings
  patch 'settings/update', to: 'settings#update', as: :update_settings
  delete 'settings/disconnect_google', to: 'settings#disconnect_google', as: :disconnect_google
  get 'settings/export_customers_with_deals', to: 'settings#export_customers_with_deals', as: :export_customers_with_deals


  # Odoo Calculator routes
  resources :odoo_proposals, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
    member do
      get  'download_pdf'
      post 'generate_narrative'
      post 'regenerate_section'
      patch 'update_narrative'
    end
    collection do
      get 'calculate'
      post 'analyze'
    end
  end

  # Cost Calculator routes
  resources :cost_estimates, only: [:index, :show, :create, :destroy] do
    collection do
      post 'analyze'
    end
    member do
      get 'generate_proposal'
      post 'resend'
    end
  end

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

  # Twilio WhatsApp webhooks (incoming messages + delivery status callbacks)
  post 'twilio/whatsapp/inbound', to: 'twilio_whatsapp#inbound'
  post 'twilio/whatsapp/status', to: 'twilio_whatsapp#status'

  # Public redirect endpoint used as the Media URL in Twilio Content templates
  # (`https://crm.tecaudex.com/wa/media/{{1}}`). Meta hits this; we 302 to S3.
  get  'wa/media/:signed_id', to: 'whatsapp_media#show', as: :wa_media

  # WhatsApp templates (admin)
  resources :whatsapp_templates, only: [:index] do
    collection do
      post :sync
    end
  end

  # API routes
  namespace :api do
    namespace :pk do
      post 'websiteleads', to: 'website_leads#create'
    end

    namespace :v1 do
      post 'cost_calculator', to: 'cost_calculator#cost_calculator'
      post 'website_lead', to: 'website_lead#create'
      post 'inbound_lead', to: 'cost_calculator#inbound_lead'
      post 'init_estimates', to: 'cost_calculator#init_estimates'
      post 'submit_estimate', to: 'cost_calculator#submit_estimate'

      resources :whatsapp, only: [:index] do
        collection do
          get 'customer/:customer_id/messages', to: 'whatsapp#show_customer_messages', as: :customer_messages
          post 'customer/:customer_id/send_text', to: 'whatsapp#send_text_message', as: :send_text
          post 'customer/:customer_id/send_image', to: 'whatsapp#send_image_message', as: :send_image
          post 'customer/:customer_id/sync', to: 'whatsapp#sync_messages', as: :sync_messages
          get 'status', to: 'whatsapp#status'
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
          post 'assign_to_self'
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
      
      resources :whatsapp, only: [:index] do
        collection do
          get 'customer/:customer_id', to: 'whatsapp#show', as: :customer_messages
          post 'customer/:customer_id', to: 'whatsapp#create', as: :send_message
          patch 'customer/:customer_id/sync', to: 'whatsapp#sync', as: :sync_messages
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
    
  end

  
  # Development login gateway (only available in development)
  if Rails.env.development?
    get '/dev_login', to: 'dev_login#show', as: :dev_login
    post '/dev_login', to: 'dev_login#create'
  end
end
