Rails.application.routes.draw do
  get "panel", to: "panel#show"
  namespace :admin do
  resources :expenses
  resources :shopping_list_items do
    collection do
      get :new_batch
      post :create_batch
    end
  end
    root to: "dashboard#show"
    resources :categories
    resources :installment_purchases
    resources :vendors
    resources :savings_goals
    resources :users
    resources :incomes, only: [ :index, :new, :create, :edit, :update, :destroy ]
    get "ahorro", to: "ahorro#show"
    get "estadisticas", to: "estadisticas#show"

    get "login", to: "sessions#new", as: :login
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout
  end

  namespace :api do
    namespace :v1 do
      post "login", to: "sessions#create"
      get "dashboard", to: "dashboard#show"
      post "incomes", to: "incomes#create"
      get "categories", to: "categories#index"
      get "expenses", to: "expenses#index"
      post "expenses", to: "expenses#create"
    end
  end
end
