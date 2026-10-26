class Api::V1::BaseController < ActionController::API
  # Idioma de los mensajes de la API. Se usa solo acá, sin tocar el idioma del back-office.
  API_LOCALE = :es
  # Campo que se informa cuando el error no es de un campo en particular.
  BASE_FIELD = "base".freeze

  around_action :use_api_locale
  before_action :authenticate_user!

  rescue_from ActiveRecord::RecordNotFound do
    render_error(api_t("not_found"), status: :not_found)
  end

  private

  def use_api_locale(&)
    I18n.with_locale(API_LOCALE, &)
  end

  def authenticate_user!
    token = request.headers["Authorization"]&.split(" ")&.last
    @current_user = AuthToken.user_from(token) if token.present?
    render_error(api_t("unauthorized"), status: :unauthorized) unless @current_user
  end

  def current_user
    @current_user
  end

  # Corta con 403 si el usuario no es administrador.
  def require_admin!
    render_error(api_t("forbidden"), status: :forbidden) unless current_user.admin?
  end

  # El admin ve los datos de todos. Un usuario común ve solo los suyos.
  def visible_expenses
    current_user.admin? ? Expense.all : current_user.expenses
  end

  def visible_incomes
    current_user.admin? ? Income.all : current_user.incomes
  end

  # Formato único de errores: { "errors": [ { "field": "...", "message": "..." } ] }

  # Un solo mensaje general (401, 403, 404...). El campo es "base".
  def render_error(message, status:, field: BASE_FIELD)
    render json: { errors: [ { field: field, message: message } ] }, status: status
  end

  # Errores de validación de un registro (422), uno por campo.
  def render_record_errors(record)
    errors = record.errors.map { |error| { field: error_field(record, error), message: error.message } }
    render json: { errors: errors }, status: :unprocessable_entity
  end

  # Un error de asociación (category) se informa con su clave foránea (category_id),
  # que es el nombre del campo que envía el front.
  def error_field(record, error)
    reflection = record.class.reflect_on_association(error.attribute)
    reflection&.belongs_to? ? reflection.foreign_key.to_s : error.attribute.to_s
  end

  # Traduce un mensaje de la API en el idioma de la API, incluso fuera del around_action.
  def api_t(key)
    I18n.t("api.errors.#{key}", locale: API_LOCALE)
  end
end
