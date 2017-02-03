Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: 'top#index'
  resources :areas, only: [:index, :show] do
    member do
      post :teleport
      post :add
      post :remove
    end
  end
end
