Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]

  resources :invitations, only: %i[index new create destroy]
  get "invitations/:token", to: "invitations#show", as: :invitation_preview
  post "invitations/:token/accept", to: "invitations#accept", as: :accept_invitation

  post "account_switch", to: "account_switches#create", as: :switch_account

  resources :channels, except: %i[show]

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

  get "catalog", to: "catalog#index"
  namespace :catalog do
    get "search", to: "search#index"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "dashboard#show"
end
