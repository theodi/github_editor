Rails.application.routes.draw do

  devise_for :users, :controllers => { :omniauth_callbacks => "auth" }
  
  devise_scope :user do
    get 'sign_out', :to => 'devise/sessions#destroy', :as => :destroy_user_session
  end
  
  root to: "home#index"
  
  constraints(path: /[^\?]+/) do
    get ":owner/:repo/blob/:branch/*path" => "home#edit", :format => false
  end

  post "/message" => "home#message"
  
  post "/commit" => "home#commit"

end
