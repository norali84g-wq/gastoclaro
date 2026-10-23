require "test_helper"

class Api::V1::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  def valid_params
    {
      user: "nueva",
      email: "nueva@example.com",
      password: "password123",
      password_confirmation: "password123"
    }
  end

  def crear_usuario_existente
    familia = FamilyGroup.create!(name: "Familia existente")
    User.create!(user: "existente", email: "existente@example.com", password: "password123", family_group: familia)
  end

  test "el registro crea el usuario con su grupo personal y devuelve el token" do
    assert_difference [ "User.count", "FamilyGroup.count" ], 1 do
      post "/api/v1/register", params: valid_params, as: :json
    end

    assert_response :created
    user = User.find_by(user: "nueva")
    assert_equal user.auth_token, response.parsed_body["token"]
    assert_equal "nueva", response.parsed_body["user"]
    assert_not user.admin?
  end

  test "el token devuelto sirve para usar la API" do
    post "/api/v1/register", params: valid_params, as: :json
    token = response.parsed_body["token"]

    get "/api/v1/expenses", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :ok
  end

  test "ignora admin y family_group_id si vienen en el pedido" do
    otra_familia = FamilyGroup.create!(name: "Otra familia")

    post "/api/v1/register",
         params: valid_params.merge(admin: true, family_group_id: otra_familia.id),
         as: :json

    assert_response :created
    user = User.find_by(user: "nueva")
    assert_not user.admin?
    assert_not_equal otra_familia.id, user.family_group_id
  end

  test "un usuario repetido da 422 y no crea nada" do
    crear_usuario_existente

    assert_no_difference [ "User.count", "FamilyGroup.count" ] do
      post "/api/v1/register", params: valid_params.merge(user: "existente"), as: :json
    end

    assert_response :unprocessable_entity
    assert_not_empty response.parsed_body["errors"]
  end

  test "un email repetido da 422, sin importar mayusculas" do
    crear_usuario_existente

    post "/api/v1/register", params: valid_params.merge(email: "EXISTENTE@example.com"), as: :json

    assert_response :unprocessable_entity
    assert_not_empty response.parsed_body["errors"]
  end

  test "sin email da 422" do
    post "/api/v1/register", params: valid_params.except(:email), as: :json

    assert_response :unprocessable_entity
  end

  test "una contrasena corta da 422" do
    corta = "a" * (User::PASSWORD_MIN_LENGTH - 1)

    post "/api/v1/register", params: valid_params.merge(password: corta, password_confirmation: corta), as: :json

    assert_response :unprocessable_entity
  end

  test "si la confirmacion no coincide da 422" do
    post "/api/v1/register", params: valid_params.merge(password_confirmation: "otra-cosa-123"), as: :json

    assert_response :unprocessable_entity
  end

  test "sin confirmacion de contrasena da 422" do
    post "/api/v1/register", params: valid_params.except(:password_confirmation), as: :json

    assert_response :unprocessable_entity
  end
end
