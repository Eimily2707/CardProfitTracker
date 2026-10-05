Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]

  resources :invitations, only: %i[index new create destroy]
  get "invitations/:token", to: "invitations#show", as: :invitation_preview
  post "invitations/:token/accept", to: "invitations#accept", as: :accept_invitation

  post "account_switch", to: "account_switches#create", as: :switch_account
  patch "locale", to: "locales#update", as: :locale

  resources :channels, except: %i[show]
  resources :expense_categories, except: %i[show]

  resources :expenses do
    member { post :confirm }
  end

  resources :purchases do
    member do
      post :confirm
      post :confirm_received
      post :receive
      post :cancel
    end
  end

  resources :sales do
    member do
      post :submit
      post :confirm_payment
      post :ship
      post :deliver
      post :cancel
    end
    collection do
      post :sync
      post :sync_one
    end
  end

  resources :inventory_items, only: %i[index show] do
    member { post :open }
  end

  resources :cost_pools, only: %i[show update] do
    member do
      post :close
      post :reopen
    end
    resources :items, only: %i[create update destroy], controller: "cost_pool_items"
  end

  get "catalog", to: "catalog#index"
  namespace :catalog do
    get "search", to: "search#index"
  end

  get "reports/sales", to: "reports#sales", as: :sales_report, defaults: { format: :csv }
  get "reports/inventory", to: "reports#inventory", as: :inventory_report, defaults: { format: :csv }

  post "webhooks/cardtrader/:webhook_token", to: "webhooks/cardtrader#create", as: :cardtrader_webhook

  resource :cardtrader_connection, only: %i[new create edit update destroy] do
    post :verify, on: :member
  end

  resources :tasks, only: %i[index] do
    member do
      post :snooze
      post :dismiss
      post :unsnooze
    end
  end

  get "audit_logs", to: "audit_logs#show", as: :audit_log

  # /up: 200 only if the app boots AND Postgres/Solid Queue are healthy (Tranche 6
  # polish, replacing Rails' default boot-only check - see HealthController).
  get "up" => "health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "dashboard#show"
end
