require "test_helper"

# Todas las respuestas de error de la API tienen el mismo formato:
# { "errors": [ { "field": "...", "message": "..." } ] }
class Api::V1::ErrorFormatTest < ActionDispatch::IntegrationTest
  setup do
    grupo = FamilyGroup.create!(name: "Grupo de prueba")
    @comun = User.create!(user: "comun", password: "password123", family_group: grupo)
    @categoria = Category.create!(name: "Comida")
  end

  def headers_for(user)
    { "Authorization" => "Bearer #{AuthToken.encode(user)}" }
  end

  test "401 sin token usa el formato unico" do
    get "/api/v1/expenses"

    assert_response :unauthorized
    assert_equal [ { "field" => "base", "message" => "No autorizado" } ], response.parsed_body["errors"]
  end

  test "401 con credenciales incorrectas usa el formato unico" do
    post "/api/v1/login", params: { user: "comun", password: "incorrecta" }

    assert_response :unauthorized
    assert_equal [ { "field" => "base", "message" => "Usuario o contraseña incorrectos" } ], response.parsed_body["errors"]
  end

  test "403 para un usuario comun usa el formato unico" do
    get "/api/v1/users", headers: headers_for(@comun)

    assert_response :forbidden
    assert_equal [ { "field" => "base", "message" => "Acceso denegado" } ], response.parsed_body["errors"]
  end

  test "422 en ingresos informa el campo y el mensaje en espanol" do
    post "/api/v1/incomes", params: { amount: 0, date: Date.current }, headers: headers_for(@comun)

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], { "field" => "amount", "message" => "debe ser mayor a 0" }
  end

  test "422 en el registro informa el campo que falta" do
    post "/api/v1/register", params: { user: "nuevo", password: "clave12345", password_confirmation: "clave12345" }

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], { "field" => "email", "message" => "no puede estar en blanco" }
  end

  test "422 en gastos con comercio inexistente" do
    post "/api/v1/expenses",
         params: { amount: 100, date: Date.current, category_id: @categoria.id, vendor_id: 999_999 },
         headers: headers_for(@comun)

    assert_response :unprocessable_entity
    assert_equal [ { "field" => "vendor_id", "message" => "no existe" } ], response.parsed_body["errors"]
  end

  test "422 en gastos con canal de compra invalido" do
    post "/api/v1/expenses",
         params: { amount: 100, date: Date.current, category_id: @categoria.id, purchase_channel: "paloma" },
         headers: headers_for(@comun)

    assert_response :unprocessable_entity
    assert_equal [ { "field" => "purchase_channel", "message" => "no es válido" } ], response.parsed_body["errors"]
  end
end
