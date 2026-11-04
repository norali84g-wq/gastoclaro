Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

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
      delete "logout", to: "sessions#destroy"
      post "register", to: "registrations#create"
      get "dashboard", to: "dashboard#show"
      get "savings", to: "savings#show"
      get "incomes", to: "incomes#index"
      post "incomes", to: "incomes#create"
      patch "incomes/:id", to: "incomes#update"
      delete "incomes/:id", to: "incomes#destroy"
      get "savings_goals", to: "savings_goals#index"
      post "savings_goals", to: "savings_goals#create"
      patch "savings_goals/:id", to: "savings_goals#update"
      delete "savings_goals/:id", to: "savings_goals#destroy"
      get "installment_purchases", to: "installment_purchases#index"
      post "installment_purchases", to: "installment_purchases#create"
      patch "installment_purchases/:id", to: "installment_purchases#update"
      delete "installment_purchases/:id", to: "installment_purchases#destroy"
      get "shopping_list_items", to: "shopping_list_items#index"
      post "shopping_list_items", to: "shopping_list_items#create"
      patch "shopping_list_items/:id", to: "shopping_list_items#update"
      delete "shopping_list_items/:id", to: "shopping_list_items#destroy"
      get "categories", to: "categories#index"
      post "categories", to: "categories#create"
      patch "categories/:id", to: "categories#update"
      get "expenses", to: "expenses#index"
      post "expenses", to: "expenses#create"
      patch "expenses/:id", to: "expenses#update"
      delete "expenses/:id", to: "expenses#destroy"
      get "me", to: "current_user#show"
      get "users", to: "users#index"
    end
  end
end
