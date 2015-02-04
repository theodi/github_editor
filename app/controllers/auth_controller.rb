class AuthController < ApplicationController
  def github    
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      session[:github_token] = request.env["omniauth.auth"]['credentials']['token']
      sign_in @user, :event => :authentication #this will throw if @user is not activated
      flash[:notice] = "Logged in" if is_navigational_format?
      
      if session[:original_path]
        redirect_to session[:original_path]
        session.delete :original_path
      else
        redirect_to root_path
      end
      
    else
      session["devise.github_data"] = request.env["omniauth.auth"]
      redirect_to root_path
    end
  end
  
end
