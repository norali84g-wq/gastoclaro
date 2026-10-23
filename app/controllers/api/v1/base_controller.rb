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

  # Corta con 403 si el usuario no es administrador.
  def require_admin!
    render json: { error: "Acceso denegado" }, status: :forbidden unless current_user.admin?
  end

  # El admin ve los datos de todos. Un usuario común ve solo los suyos.
  def visible_expenses
    current_user.admin? ? Expense.all : current_user.expenses
  end

  def visible_incomes
    current_user.admin? ? Income.all : current_user.incomes
  end
end
