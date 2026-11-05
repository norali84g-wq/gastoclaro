class Api::V1::SessionsController < Api::V1::BaseController
  skip_before_action :authenticate_user!, only: [ :create ]

  def create
    user = User.authenticate_by(user: params[:user].to_s, password: params[:password].to_s)
    if user
      render json: SessionSerializer.call(user)
    else
      render_error(api_t("invalid_credentials"), status: :unauthorized)
    end
  end

  # Cierra la sesión: invalida todos los tokens emitidos para el usuario.
  def destroy
    current_user.revoke_tokens!
    head :no_content
  end
end
