# Arma la respuesta de login y registro: el token, cuándo vence y los datos del usuario.
class SessionSerializer
  def self.call(user)
    expires_at = AuthToken::EXPIRATION.from_now
    {
      token: AuthToken.encode(user, expires_at),
      expires_at: expires_at.iso8601,
      user: UserSerializer.call(user)
    }
  end
end
