class Api::V1::SessionsController < Api::V1::BaseController
  skip_before_action :authenticate_user!, only: [ :create ]

  def create
    user = User.find_by(user: params[:user])
    if user&.authenticate(params[:password])
      render json: { token: user.auth_token, user: user.user }
    else
      render json: { error: "Usuario o contraseña incorrectos" }, status: :unauthorized
    end
  end
end
