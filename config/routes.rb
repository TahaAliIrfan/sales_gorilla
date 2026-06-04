Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # =========================================================================
  # ROOT / MARKETING / ACCOUNT area — bare domain or platform subdomains
  # (www / admin / app / api / crm). Authentication, organization management,
  # public invoices, webhooks, and the JSON APIs live here.
  # =========================================================================
  constraints(RootDomain) do
    # Marketing landing.
    root "home#index"

    # Authentication.
    get '/auth/:provider/callback', to: 'sessions#create'
    get '/auth/failure', to: 'sessions#failure'
    get '/signout', to: 'sessions#destroy', as: :signout
    get '/signin', to: 'sessions#new', as: :signin
    get '/auth/google_oauth2', to: 'sessions#new', as: :google_oauth2

    # Organization management (signed-in users only — enforced in controller).
    resources :organizations, only: %i[index new create] do
      get :check_subdomain, on: :collection
    end

    # Dev login (only available in development).
    if Rails.env.development?
      get '/dev_login', to: 'dev_login#show', as: :dev_login
      post '/dev_login', to: 'dev_login#create'
    end

    # Public-facing endpoints (no tenant required).
    get 'i/:token/pdf', to: 'public_invoices#download_pdf', as: :public_invoice_pdf
    get 'i/:token',     to: 'public_invoices#show',         as: :public_invoice
    post 'i/:token/payment_proof', to: 'public_invoices#upload_payment_proof', as: :public_invoice_payment_proof

    # Webhooks (external services hit the root host).
    match 'webhook', to: 'messages#webhook', via: [:get, :post]
    post 'twilio/whatsapp/inbound', to: 'twilio_whatsapp#inbound'
    post 'twilio/whatsapp/status',  to: 'twilio_whatsapp#status'
    get  'wa/media/:signed_id', to: 'whatsapp_media#show', as: :wa_media

    # API namespaces (JWT-authenticated, tenant resolved via header in future).
    namespace :api do
      namespace :pk do
        post 'websiteleads', to: 'website_leads#create'
      end

      namespace :v1 do
        post 'cost_calculator', to: 'cost_calculator#cost_calculator'
        post 'website_lead',    to: 'website_lead#create'
        post 'inbound_lead',    to: 'cost_calculator#inbound_lead'
        post 'init_estimates',  to: 'cost_calculator#init_estimates'
        post 'submit_estimate', to: 'cost_calculator#submit_estimate'

        resources :whatsapp, only: [:index] do
          collection do
            get 'customer/:customer_id/messages',   to: 'whatsapp#show_customer_messages', as: :customer_messages
            post 'customer/:customer_id/send_text', to: 'whatsapp#send_text_message',      as: :send_text
            post 'customer/:customer_id/send_image',to: 'whatsapp#send_image_message',     as: :send_image
            post 'customer/:customer_id/sync',      to: 'whatsapp#sync_messages',          as: :sync_messages
            get  'status', to: 'whatsapp#status'
          end
        end
      end

      namespace :v2 do
        post   'auth/login',          to: 'authentication#login'
        post   'auth/google_sign_in', to: 'authentication#google_sign_in'
        delete 'auth/logout',         to: 'authentication#logout'
        get    'auth/profile',        to: 'authentication#profile'

        # Multi-tenant: list the user's organizations, switch into one (returns
        # a new JWT carrying the org claim), and inspect the current org.
        resources :organizations, only: %i[index] do
          collection do
            post 'switch',  to: 'organizations#switch'
            get  'current', to: 'organizations#show'
          end
        end

        resources :customers do
          member do
            patch 'update_status'
            patch 'update_communication_status'
            get   'whatsapp_messages'
            post  'send_whatsapp_text'
            post  'send_whatsapp_media'
            post  'analyze_phone'
            get   'recordings'
            post  'assign_to_self'
          end
          collection do
            post 'bulk_assign'
            post 'bulk_status_change'
          end
        end

        resources :deals do
          collection { get 'my_deals' }
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
          member { patch 'update_fcm_token' }
        end
        resources :recordings
        resources :pipelines
        resources :deal_stages
        resources :notifications
        resources :emails

        resources :whatsapp, only: [:index] do
          collection do
            get   'customer/:customer_id',       to: 'whatsapp#show',   as: :customer_messages
            post  'customer/:customer_id',       to: 'whatsapp#create', as: :send_message
            patch 'customer/:customer_id/sync',  to: 'whatsapp#sync',   as: :sync_messages
          end
        end

        scope :whatsapp_us, controller: 'whatsapp_us' do
          get  'conversations',                       action: :conversations,   as: :whatsapp_us_conversations
          get  'latest',                              action: :latest,          as: :whatsapp_us_latest
          get  'customers/:customer_id/messages',     action: :messages,        as: :whatsapp_us_customer_messages
          post 'customers/:customer_id/send',         action: :send_message,    as: :whatsapp_us_send_message
          post 'customers/:customer_id/send_template', action: :send_template,  as: :whatsapp_us_send_template
          post 'customers/:customer_id/mark_read',    action: :mark_read,       as: :whatsapp_us_mark_read
          get  'templates',                           action: :templates,       as: :whatsapp_us_templates
          post 'templates/sync',                      action: :sync_templates,  as: :whatsapp_us_sync_templates
        end

        get 'twilio/token', to: 'twilio#token'
      end
    end

    # Test routes
    get 'test/cost_calculator', to: redirect('/test_cost_calculator_api.html')
  end

  # =========================================================================
  # TENANT area — served from an organization subdomain (e.g. acme.tecaudex.com).
  # All CRM features live here. Membership in the org is enforced by
  # ApplicationController#authorize_tenant_request!.
  # =========================================================================
  constraints(TenantSubdomain) do
    root "user_dashboard#index", as: :tenant_root

    # Organization branding & switcher.
    resource :branding, only: %i[edit update], controller: "branding"

    # Sidekiq dashboard (admin only).
    require 'sidekiq/web'
    authenticate = lambda do |request|
      user_id = request.session[:user_id]
      user = User.find_by(id: user_id)
      user&.admin?
    end
    constraints authenticate do
      mount Sidekiq::Web => '/sidekiq'
    end

    # User management.
    get 'manager/dashboard', to: 'manager#dashboard', as: 'manager_dashboard'
    get 'users/index'
    get 'users/show'
    get 'users/associates'
    get 'users/managers'

    resources :users, only: %i[index show] do
      member do
        post   :update_role
        post   :toggle_active
        get    :manage_associates
        post   :assign_associate
        delete :remove_associate
      end
      collection do
        get :associates
        get :managers
      end
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

    resources :csv_imports, only: %i[new] do
      collection do
        post   'upload'
        get    'mapping'
        post   'import'
        delete 'cancel'
      end
    end

    resources :customer_groups do
      member do
        post   'add_customer'
        delete 'remove_customer'
      end
    end

    resources :campaigns do
      member do
        post   'send_now'
        post   'schedule'
        post   'restart'
        post   'stop'
        post   'add_customers'
        delete 'remove_customer'
      end
    end

    get 'invoices', to: 'all_invoices#index', as: :invoices

    resources :customers do
      member do
        patch 'update_status'
        patch 'update_communication_status'
        post  'analyze_phone'
        post  'calculate_lead_score'
        post  'assign_to_self'
        post  'upload_documents'
        post  'mark_lead_quality'
      end

      resources :invoices do
        member do
          get   :download_pdf
          patch :mark_paid
        end
      end
      resources :milestones do
        member do
          patch :mark_paid
          patch :mark_unpaid
        end
        resources :milestone_items, only: %i[create update]
      end

      resources :followups, controller: 'customer_followups', only: %i[new create]

      resources :emails do
        collection { get 'fetch' }
        member do
          post 'mark_as_read'
          get  'export_pdf'
          post 'send_draft'
        end
        resources :attachments, controller: 'email_attachments', only: %i[show] do
          member { get 'download' }
        end
      end

      resources :messages, only: %i[index create] do
        collection do
          patch  'sync'
          delete 'refresh'
        end
      end

      get  'whatsapp_us',                 to: 'whatsapp_us#index'
      post 'whatsapp_us',                 to: 'whatsapp_us#create'
      get  'whatsapp_us/templates',       to: 'whatsapp_us#templates'
      post 'whatsapp_us/templates/sync',  to: 'whatsapp_us#sync_templates'
      post 'whatsapp_us/send_template',   to: 'whatsapp_us#send_template'
      post 'whatsapp_us/sync_chat',       to: 'whatsapp_us#sync_chat'
      post 'whatsapp_us/lookup_phone',    to: 'whatsapp_us#lookup_phone'

      collection do
        post 'bulk_assign'
        post 'bulk_status_change'
        get  'export_csv'
      end
    end

    resources :pipelines do
      member { patch 'assign_users' }
      resources :deal_stages, except: [:index]
    end
    resources :deal_stages, only: [:index]
    resources :tasks do
      member { patch 'complete' }
      collection { get 'my_tasks' }
    end
    resources :deals do
      collection { get 'my_deals', to: 'deals#my_deals' }
      member do
        patch 'update_stage'
        patch 'mark_as_won'
        patch 'mark_as_lost'
        patch 'assign_user'
      end
    end

    resources :notifications, only: %i[index show] do
      member     { post 'mark_as_read' }
      collection { post 'mark_all_as_read' }
    end

    get 'reports',             to: 'reports#index',      as: :reports
    get 'reports/my_reports',  to: 'reports#my_reports', as: :my_reports

    get 'my_dashboard',       to: 'user_dashboard#index',     as: :dashboard
    get 'my_tasks_dashboard', to: 'my_tasks_dashboard#index', as: :my_tasks_dashboard

    get    'settings',                           to: 'settings#edit',                       as: :settings
    patch  'settings/update',                    to: 'settings#update',                     as: :update_settings
    delete 'settings/disconnect_google',         to: 'settings#disconnect_google',          as: :disconnect_google
    get    'settings/export_customers_with_deals', to: 'settings#export_customers_with_deals', as: :export_customers_with_deals

    resources :odoo_proposals, only: %i[index new create show edit update destroy] do
      member do
        get   'download_pdf'
        post  'generate_narrative'
        post  'regenerate_section'
        patch 'update_narrative'
      end
      collection do
        get  'calculate'
        post 'analyze'
      end
    end

    resources :cost_estimates, only: %i[index show create destroy] do
      collection { post 'analyze' }
      member do
        get  'generate_proposal'
        post 'resend'
      end
    end

    # Browser-based calling.
    get   'calling',                   to: 'calling#index'
    get   'calling/token',             to: 'calling#token'
    match 'calling/voice',             to: 'calling#voice', via: %i[get post]
    get   'calling/available_numbers', to: 'calling#available_numbers'
    post  'calling/store_customer_id', to: 'calling#store_customer_id'

    get  'calling/recordings',            to: 'calling#recordings'
    get  'calling/recording/:sid',        to: 'calling#recording',         as: :get_recording
    get  'calling/play_recording/:sid',   to: 'calling#play_recording',    as: :calling_play_recording
    post 'calling/recording_status',      to: 'calling#recording_status'

    resources :whatsapp_templates, only: %i[index] do
      collection { post :sync }
    end

    resources :recordings, only: %i[index show] do
      member do
        get :transcript
        get :download
      end
      collection { get :my_recordings }
    end
  end
end
