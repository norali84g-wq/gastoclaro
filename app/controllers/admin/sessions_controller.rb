class Admin::SessionsController < ApplicationController
  layout "admin"

  def new
  end

  def create
    user = User.find_by(user: params[:user], admin: true)
    if user&.authenticate(params[:password])
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
