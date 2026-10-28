require "test_helper"

class Api::V1::CurrentUserControllerTest < ActionDispatch::IntegrationTest
  setup do
    grupo = FamilyGroup.create!(name: "Grupo de prueba")
    @comun = User.create!(user: "comun", email: "comun@example.com", password: "password123", family_group: grupo)
    @admin = User.create!(user: "jefa", password: "password123", family_group: grupo, admin: true)
  end

  def headers_for(user)
    { "Authorization" => "Bearer #{AuthToken.encode(user)}" }
  end

  test "me devuelve el usuario del token" do
    get "/api/v1/me", headers: headers_for(@comun)

    assert_response :ok
    esperado = { "id" => @comun.id, "user" => "comun", "email" => "comun@example.com", "admin" => false }
    assert_equal esperado, response.parsed_body
  end

  test "me informa si el usuario es admin" do
    get "/api/v1/me", headers: headers_for(@admin)

    assert_response :ok
    assert_equal true, response.parsed_body["admin"]
  end

  test "me sin token da 401" do
    get "/api/v1/me"

    assert_response :unauthorized
  end

  test "el login devuelve el mismo objeto de usuario que me" do
    post "/api/v1/login", params: { user: "comun", password: "password123" }
    usuario_del_login = response.parsed_body["user"]
    token = response.parsed_body["token"]

    get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }

    assert_equal usuario_del_login, response.parsed_body
  end

  test "el login informa cuando vence el token" do
    post "/api/v1/login", params: { user: "comun", password: "password123" }

    vence = Time.zone.parse(response.parsed_body["expires_at"])
    assert_in_delta AuthToken::EXPIRATION.from_now.to_f, vence.to_f, 60
  end
end
