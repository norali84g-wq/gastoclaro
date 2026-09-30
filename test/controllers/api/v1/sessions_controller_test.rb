require "test_helper"

class Api::V1::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    familia = FamilyGroup.create!(name: "Familia de prueba")
    @user = User.create!(user: "tester", password: "password123", family_group: familia)
  end

  test "login con credenciales correctas devuelve el token del usuario" do
    post "/api/v1/login", params: { user: "tester", password: "password123" }, as: :json

    assert_response :ok
    assert_equal @user.auth_token, response.parsed_body["token"]
    assert_equal "tester", response.parsed_body["user"]
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
end
