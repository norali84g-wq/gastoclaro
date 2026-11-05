class Admin::SessionsController < ApplicationController
  layout "admin"

  def new
  end

  def create
    user = User.authenticate_by(user: params[:user].to_s, password: params[:password].to_s, admin: true)
    if user
      session[:admin_user_id] = user.id
      redirect_to admin_root_path, notice: "Bienvenido, #{user.user}"
    else
      flash.now[:alert] = "Usuario o contraseña incorrectos"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:admin_user_id] = nil
    redirect_to admin_login_path, notice: "Sesión cerrada"
  end
end
