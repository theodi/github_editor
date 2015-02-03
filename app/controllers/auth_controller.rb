class AuthController < ApplicationController
  def github    
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      session[:github_token] = request.env["omniauth.auth"]['credentials']['token']
      sign_in_and_redirect @user, :event => :authentication #this will throw if @user is not activated
      flash[:notice] = "Logged in" if is_navigational_format?
    else
      session["devise.github_data"] = request.env["omniauth.auth"]
      redirect_to new_user_registration_url
    end
  end
  
end
