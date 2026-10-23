class Api::V1::BaseController < ActionController::API
  before_action :authenticate_user!

  private

  def authenticate_user!
    token = request.headers["Authorization"]&.split(" ")&.last
    @current_user = User.find_by(auth_token: token) if token.present?
    render json: { error: "No autorizado" }, status: :unauthorized unless @current_user
  end

  def current_user
    @current_user
  end
end
