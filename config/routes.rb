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

    # Devise email/password sign-in. We skip all auto-generated routes and
    # define the ones we want explicitly so we get clean paths (/signin,
    # /signup, /password) without polluting the root with /edit, /cancel,
    # POST /, etc. that `path: ""` would create.
    devise_for :users, skip: :all
    devise_scope :user do
      get  "signin", to: "users/sessions#new",        as: :new_user_session
      post "signin", to: "users/sessions#create",     as: :user_session

      get  "signup", to: "users/registrations#new",   as: :new_user_registration
      post "signup", to: "users/registrations#create", as: :user_registration

      get   "password/new",  to: "users/passwords#new",    as: :new_user_password
      get   "password/edit", to: "users/passwords#edit",   as: :edit_user_password
      patch "password",      to: "users/passwords#update", as: :user_password
      post  "password",      to: "users/passwords#create"

      get  "confirmation/new", to: "users/confirmations#new",  as: :new_user_confirmation
      get  "confirmation",     to: "users/confirmations#show", as: :user_confirmation
      post "confirmation",     to: "users/confirmations#create"
    end

    # Google OAuth (omniauth) — still wired through SessionsController.
    get "/auth/:provider/callback", to: "sessions#create"
    get "/auth/failure", to: "sessions#failure"
    get "/signout", to: "sessions#destroy", as: :signout
    get "/auth/google_oauth2", to: "sessions#new", as: :google_oauth2

    # Organization management (signed-in users only — enforced in controller).
    resources :organizations, only: %i[index new create] do
      get :check_subdomain, on: :collection
    end

    # Dev login (only available in development).
   # if Rails.env.development?
      get "/dev_login", to: "dev_login#show", as: :dev_login
      post "/dev_login", to: "dev_login#create"
   # end

    # Public-facing endpoints (no tenant required).
    get "i/:token/pdf", to: "public_invoices#download_pdf", as: :public_invoice_pdf
    get "i/:token",     to: "public_invoices#show",         as: :public_invoice
    post "i/:token/payment_proof", to: "public_invoices#upload_payment_proof", as: :public_invoice_payment_proof

    # Webhooks (external services hit the root host).
    match "webhook", to: "messages#webhook", via: [ :get, :post ]
    post "twilio/whatsapp/inbound", to: "twilio_whatsapp#inbound"
    post "twilio/whatsapp/status",  to: "twilio_whatsapp#status"
    get  "wa/media/:signed_id", to: "whatsapp_media#show", as: :wa_media

    # Meta Lead Ads webhook (single global endpoint for ALL orgs; org resolved
    # by page_id). GET = subscription verification, POST = leadgen delivery.
    # `/webhooks/facebook` is the canonical URL registered in the Meta App
    # dashboard; `/webhooks/meta/lead_ads` is kept as an alias.
    namespace :webhooks do
      get  "facebook",      to: "meta_lead_ads#verify"
      post "facebook",      to: "meta_lead_ads#receive"
      get  "meta/lead_ads", to: "meta_lead_ads#verify"
      post "meta/lead_ads", to: "meta_lead_ads#receive"
    end

    # Self-service Facebook connect flow (fixed redirect URI required by Meta,
    # so it lives on the root host and carries the org via signed state).
    get "meta_lead_ads/connect",  to: "meta_lead_ads/connections#connect",  as: :meta_lead_ads_connect
    get "meta_lead_ads/callback", to: "meta_lead_ads/connections#callback", as: :meta_lead_ads_callback

    # Email open-tracking pixel. Short path keeps the URL small in emails; the
    # .gif suffix makes it look like a static image to recipient mail clients.
    get "/e/o/:token.gif", to: "email_tracking#open", as: :email_open_tracking,
        constraints: { token: %r{[A-Za-z0-9_-]+} }

    # API namespaces (JWT-authenticated, tenant resolved via header in future).
    namespace :api do
      namespace :pk do
        post "websiteleads", to: "website_leads#create"
      end

      namespace :v1 do
        post "cost_calculator", to: "cost_calculator#cost_calculator"
        post "website_lead",    to: "website_lead#create"
        post "inbound_lead",    to: "cost_calculator#inbound_lead"
        post "init_estimates",  to: "cost_calculator#init_estimates"
        post "submit_estimate", to: "cost_calculator#submit_estimate"

        resources :whatsapp, only: [ :index ] do
          collection do
            get "customer/:customer_id/messages",   to: "whatsapp#show_customer_messages", as: :customer_messages
            post "customer/:customer_id/send_text", to: "whatsapp#send_text_message",      as: :send_text
            post "customer/:customer_id/send_image", to: "whatsapp#send_image_message",     as: :send_image
            post "customer/:customer_id/sync",      to: "whatsapp#sync_messages",          as: :sync_messages
            get  "status", to: "whatsapp#status"
          end
        end
      end

      namespace :v2 do
        post   "auth/login",          to: "authentication#login"
        post   "auth/google_sign_in", to: "authentication#google_sign_in"
        delete "auth/logout",         to: "authentication#logout"
        get    "auth/profile",        to: "authentication#profile"

        # Multi-tenant: list the user's organizations, switch into one (returns
        # a new JWT carrying the org claim), and inspect the current org.
        resources :organizations, only: %i[index] do
          collection do
            post "switch",  to: "organizations#switch"
            get  "current", to: "organizations#show"
          end
        end

        resources :customers do
          member do
            patch "update_status"
            patch "update_communication_status"
            get   "whatsapp_messages"
            post  "send_whatsapp_text"
            post  "send_whatsapp_media"
            post  "analyze_phone"
            get   "recordings"
            post  "assign_to_self"
          end
          collection do
            post "bulk_assign"
            post "bulk_status_change"
          end
        end

        resources :deals do
          collection { get "my_deals" }
          member do
            patch "update_stage"
            patch "mark_as_won"
            patch "mark_as_lost"
            patch "assign_user"
          end
        end

        resources :tasks do
          member do
            patch "mark_as_completed"
            patch "mark_as_pending"
          end
        end

        resources :users do
          member { patch "update_fcm_token" }
        end
        resources :recordings
        resources :pipelines
        resources :deal_stages
        resources :notifications
        resources :emails

        resources :whatsapp, only: [ :index ] do
          collection do
            get   "customer/:customer_id",       to: "whatsapp#show",   as: :customer_messages
            post  "customer/:customer_id",       to: "whatsapp#create", as: :send_message
            patch "customer/:customer_id/sync",  to: "whatsapp#sync",   as: :sync_messages
          end
        end

        scope :whatsapp_us, controller: "whatsapp_us" do
          get  "conversations",                       action: :conversations,   as: :whatsapp_us_conversations
          get  "latest",                              action: :latest,          as: :whatsapp_us_latest
          get  "customers/:customer_id/messages",     action: :messages,        as: :whatsapp_us_customer_messages
          post "customers/:customer_id/send",         action: :send_message,    as: :whatsapp_us_send_message
          post "customers/:customer_id/send_template", action: :send_template,  as: :whatsapp_us_send_template
          post "customers/:customer_id/mark_read",    action: :mark_read,       as: :whatsapp_us_mark_read
          get  "templates",                           action: :templates,       as: :whatsapp_us_templates
          post "templates/sync",                      action: :sync_templates,  as: :whatsapp_us_sync_templates
        end

        get "twilio/token", to: "twilio#token"
      end
    end

    # Test routes
    get "test/cost_calculator", to: redirect("/test_cost_calculator_api.html")
  end

  # =========================================================================
  # TENANT area — served from an organization subdomain (e.g. acme.tecaudex.com).
  # All CRM features live here. Membership in the org is enforced by
  # ApplicationController#authorize_tenant_request!.
  # =========================================================================
  constraints(TenantSubdomain) do
    root "user_dashboard#index", as: :tenant_root

    # Relay redesign styleguide (development only).
    get "_relay", to: "relay_styleguide#index" if Rails.env.development?

    # Organization branding & switcher.
    resource :branding, only: %i[edit update], controller: "branding"

    # Sidekiq dashboard (admin only).
    require "sidekiq/web"
    authenticate = lambda do |request|
      user_id = request.session[:user_id]
      user = User.find_by(id: user_id)
      user&.admin?
    end
    constraints authenticate do
      mount Sidekiq::Web => "/sidekiq"
    end

    # User management.
    get "manager/dashboard", to: "manager#dashboard", as: "manager_dashboard"
    get "users/index"
    get "users/show"
    get "users/associates"
    get "users/managers"

    resources :users, only: %i[index show] do
      member do
        post   :update_role
        post   :toggle_active
        post   :resend_invite
        get    :manage_associates
        post   :assign_associate
        delete :remove_associate
      end
      collection do
        get :associates
        get :managers
        post :invite
      end
    end

    # Per-org roles & permissions management.
    resources :roles

    get "tasks/index"
    get "tasks/show"
    get "tasks/new"
    get "tasks/edit"
    get "tasks/create"
    get "tasks/update"
    get "tasks/destroy"
    get "tasks/complete"
    get "settings/edit"
    get "settings/update"

    resources :csv_imports, only: %i[new] do
      collection do
        post   "upload"
        get    "mapping"
        post   "import"
        delete "cancel"
      end
    end

    resources :customer_groups do
      member do
        post   "add_customer"
        delete "remove_customer"
      end
    end

    resources :campaigns do
      member do
        post   "send_now"
        post   "schedule"
        post   "restart"
        post   "stop"
        post   "add_customers"
        delete "remove_customer"
      end
    end

    get "invoices", to: "all_invoices#index", as: :invoices

    resources :customers do
      member do
        patch "update_status"
        patch "update_communication_status"
        post  "analyze_phone"
        post  "calculate_lead_score"
        post  "assign_to_self"
        post  "upload_documents"
        post  "mark_lead_quality"
        post  "add_note"
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

      resources :followups, controller: "customer_followups", only: %i[new create]

      resources :emails do
        collection { get "fetch" }
        member do
          post "mark_as_read"
          get  "export_pdf"
          post "send_draft"
        end
        resources :attachments, controller: "email_attachments", only: %i[show] do
          member { get "download" }
        end
      end

      resources :messages, only: %i[index create] do
        collection do
          patch  "sync"
          delete "refresh"
        end
      end

      get  "whatsapp_us",                 to: "whatsapp_us#index"
      post "whatsapp_us",                 to: "whatsapp_us#create"
      get  "whatsapp_us/templates",       to: "whatsapp_us#templates"
      post "whatsapp_us/templates/sync",  to: "whatsapp_us#sync_templates"
      post "whatsapp_us/send_template",   to: "whatsapp_us#send_template"
      post "whatsapp_us/sync_chat",       to: "whatsapp_us#sync_chat"
      post "whatsapp_us/lookup_phone",    to: "whatsapp_us#lookup_phone"

      collection do
        post "bulk_assign"
        post "bulk_status_change"
        get  "export_csv"
      end
    end

    resources :pipelines do
      member { patch "assign_users" }
      resources :deal_stages, except: [ :index ]
    end
    resources :deal_stages, only: [ :index ]
    resources :tasks do
      member { patch "complete" }
      collection { get "my_tasks" }
    end
    resources :deals do
      collection { get "my_deals", to: "deals#my_deals" }
      member do
        patch "update_stage"
        patch "mark_as_won"
        patch "mark_as_lost"
        patch "assign_user"
      end
    end

    resources :notifications, only: %i[index show] do
      member     { post "mark_as_read" }
      collection { post "mark_all_as_read" }
    end

    # Relay Inbox (Phase 6): cross-lead conversation triage. The optional
    # :customer_id selects which thread shows in the right pane, so inbox_path
    # works both bare and with a lead id.
    get "inbox(/:customer_id)", to: "inbox#index", as: :inbox

    # Relay Outreach (Phase 7): one workspace over campaigns, audiences
    # (customer groups) and WhatsApp templates. ?tab=campaigns|audiences|templates
    # picks the active tab so each is linkable. The legacy CRUD routes above stay.
    get "outreach", to: "outreach#index", as: :outreach

    # Relay Billing (Phase 9): one Quotes & invoices workspace over invoices
    # (across customers), cost estimates and Odoo proposals.
    # ?tab=invoices|estimates|proposals picks the active tab so each is linkable.
    # The legacy all_invoices / cost_estimates / odoo_proposals pages stay.
    get "billing", to: "billing#index", as: :billing

    get "reports",             to: "reports#index",      as: :reports
    get "reports/my_reports",  to: "reports#my_reports", as: :my_reports

    get "my_dashboard",       to: "user_dashboard#index",     as: :dashboard
    get "my_tasks_dashboard", to: "my_tasks_dashboard#index", as: :my_tasks_dashboard

    get    "settings",                           to: "settings#edit",                       as: :settings
    patch  "settings/update",                    to: "settings#update",                     as: :update_settings
    delete "settings/disconnect_google",         to: "settings#disconnect_google",          as: :disconnect_google
    get    "settings/export_customers_with_deals", to: "settings#export_customers_with_deals", as: :export_customers_with_deals

    # Modular ERP feature toggles (per-organization).
    namespace :settings do
      resources :features, only: %i[index update], param: :key,
                constraints: { key: /[a-z_]+/ } do
        member do
          post :test    # provider-specific diagnostic (e.g. send a test event)
          post :verify  # provider-specific credential verification
        end
      end

      # Connected Facebook Pages for Lead Ads (set per-page lead source /
      # disconnect). The OAuth connect itself lives on the root host.
      resources :meta_page_connections, only: %i[update destroy]

      # Editable lookup lists (lead sources, statuses, project types …).
      # Admin-only via TaxonomyPolicy.
      resources :taxonomies, only: %i[index create update destroy] do
        collection { post :reorder }
        member     { get  :usage }
      end
    end

    resources :odoo_proposals, only: %i[index new create show edit update destroy] do
      member do
        get   "download_pdf"
        post  "generate_narrative"
        post  "regenerate_section"
        patch "update_narrative"
      end
      collection do
        get  "calculate"
        post "analyze"
      end
    end

    resources :cost_estimates, only: %i[index show create destroy] do
      collection { post "analyze" }
      member do
        get  "generate_proposal"
        post "resend"
      end
    end

    # Browser-based calling lives entirely in the Calling engine. The mount
    # owns `/calling/*`. Host code references the engine root via `calling_path`
    # (the default helper from `mount`).
    mount Calling::Engine => "/calling", as: :calling

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
