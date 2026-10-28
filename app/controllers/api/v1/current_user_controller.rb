class Api::V1::CurrentUserController < Api::V1::BaseController
  # Devuelve el usuario del token. Sirve para saber quién está logueado y si es admin.
  def show
    render json: UserSerializer.call(current_user)
  end
end
