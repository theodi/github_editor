Rails.application.routes.draw do

  devise_for :users, :controllers => { :omniauth_callbacks => "auth" }
  
  devise_scope :user do
    get 'sign_out', :to => 'devise/sessions#destroy', :as => :destroy_user_session
  end
  
  root to: "home#index"
  
  get ":user/:repo/blob/:branch/*path" => "home#edit"
  
end
