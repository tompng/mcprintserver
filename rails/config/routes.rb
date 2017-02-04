Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: 'top#index'
  resources :areas, only: [:index, :show], param: :i_j do
    collection do
      get :mcmap
      get :user_list
    end
    member do
      get :obj
      post :teleport
      post :add_demo_account
      post :remove_demo_account
    end
  end
end
