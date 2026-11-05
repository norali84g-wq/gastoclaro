require "test_helper"

class Api::V1::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    familia = FamilyGroup.create!(name: "Familia de prueba")
    @user = User.create!(user: "tester", password: "password123", family_group: familia)
  end

  test "login con credenciales correctas devuelve el token del usuario" do
    post "/api/v1/login", params: { user: "tester", password: "password123" }, as: :json

    assert_response :ok
    assert_equal @user, AuthToken.user_from(response.parsed_body["token"])
    assert_equal "tester", response.parsed_body["user"]["user"]
  end

  test "login con contrasena incorrecta da 401" do
    post "/api/v1/login", params: { user: "tester", password: "equivocada" }, as: :json

    assert_response :unauthorized
    assert_nil response.parsed_body["token"]
  end

  test "login con usuario inexistente da 401" do
    post "/api/v1/login", params: { user: "nadie", password: "password123" }, as: :json

    assert_response :unauthorized
  end

  test "login con el nombre de usuario en mayusculas devuelve el token" do
    post "/api/v1/login", params: { user: "TESTER", password: "password123" }, as: :json

    assert_response :ok
    assert_equal @user, AuthToken.user_from(response.parsed_body["token"])
  end

  test "login con el nombre de usuario con la primera letra en mayuscula devuelve el token" do
    post "/api/v1/login", params: { user: "Tester", password: "password123" }, as: :json

    assert_response :ok
  end

  test "login con espacios alrededor del nombre de usuario devuelve el token" do
    post "/api/v1/login", params: { user: " tester ", password: "password123" }, as: :json

    assert_response :ok
  end

  test "password_remains_case_sensitive" do
    post "/api/v1/login", params: { user: "tester", password: "PASSWORD123" }, as: :json

    assert_response :unauthorized
    assert_nil response.parsed_body["token"]
  end

  test "login con clave incorrecta responde con el formato de error unico" do
    post "/api/v1/login", params: { user: "tester", password: "equivocada" }, as: :json

    assert_response :unauthorized
    assert_equal [ { "field" => "base", "message" => "Usuario o contraseña incorrectos" } ],
                 response.parsed_body["errors"]
  end

  test "usuario inexistente y clave incorrecta dan el mismo error" do
    post "/api/v1/login", params: { user: "tester", password: "equivocada" }, as: :json
    con_clave_mala = response.parsed_body

    post "/api/v1/login", params: { user: "nadie", password: "password123" }, as: :json

    assert_response :unauthorized
    assert_equal con_clave_mala, response.parsed_body
  end

  test "login sin clave da 401 y no un error del servidor" do
    post "/api/v1/login", params: { user: "tester" }, as: :json

    assert_response :unauthorized
  end
end
