class Api::V1::SessionsController < Api::V1::BaseController
  skip_before_action :authenticate_user!, only: [ :create ]

  def create
    user = User.find_by(user: params[:user])
    if user&.authenticate(params[:password])
      render json: SessionSerializer.call(user)
    else
      render json: { error: "Usuario o contraseña incorrectos" }, status: :unauthorized
    end
  end

  # Cierra la sesión: invalida todos los tokens emitidos para el usuario.
  def destroy
    current_user.revoke_tokens!
    head :no_content
  end
end
