# Crea y valida los tokens de sesión de la API (JWT).
class AuthToken
  EXPIRATION = 24.hours
  ALGORITHM = "HS256".freeze

  def self.encode(user)
    payload = { sub: user.id.to_s, ver: user.token_version, exp: EXPIRATION.from_now.to_i }
    JWT.encode(payload, secret, ALGORITHM)
  end

  # Devuelve el usuario dueño del token, o nil si el token es inválido,
  # está vencido o fue invalidado por un logout.
  def self.user_from(token)
    payload, = JWT.decode(token, secret, true, algorithm: ALGORITHM)
    user = User.find_by(id: payload["sub"])
    user if user && user.token_version == payload["ver"]
  rescue JWT::DecodeError
    nil
  end

  def self.secret
    Rails.application.secret_key_base
  end
  private_class_method :secret
end
