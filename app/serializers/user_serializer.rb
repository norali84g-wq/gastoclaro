# Arma el JSON de un usuario. Lo usan /me, login, registro y /users
# para que todos devuelvan siempre la misma forma.
class UserSerializer
  def self.call(user)
    { id: user.id, user: user.user, email: user.email, admin: user.admin }
  end
end
