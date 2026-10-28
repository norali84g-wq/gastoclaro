require "test_helper"

class Api::V1::DataScopingTest < ActionDispatch::IntegrationTest
  setup do
    # Los tres comparten grupo a propósito: el filtro es por usuario, no por grupo.
    @grupo = FamilyGroup.create!(name: "Grupo de prueba")
    @comun = User.create!(user: "comun", password: "password123", family_group: @grupo)
    @otro = User.create!(user: "otro", password: "password123", family_group: @grupo)
    @admin = User.create!(user: "jefa", password: "password123", family_group: @grupo, admin: true)

    @categoria = Category.create!(name: "Comida")
    Expense.create!(user: @comun, category: @categoria, amount: 100, date: Date.current, description: "del comun")
    Expense.create!(user: @otro, category: @categoria, amount: 200, date: Date.current, description: "del otro")
    Income.create!(user: @comun, amount: 1000, date: Date.current)
    Income.create!(user: @otro, amount: 500, date: Date.current)
  end

  def headers_for(user)
    { "Authorization" => "Bearer #{AuthToken.encode(user)}" }
  end

  test "un usuario comun ve solo sus propios gastos" do
    get "/api/v1/expenses", headers: headers_for(@comun)

    assert_response :ok
    assert_equal [ "del comun" ], response.parsed_body.map { |g| g["description"] }
  end

  test "el admin ve los gastos de todos" do
    get "/api/v1/expenses", headers: headers_for(@admin)

    assert_response :ok
    assert_equal [ "del comun", "del otro" ], response.parsed_body.map { |g| g["description"] }.sort
  end

  test "el dashboard de un usuario comun suma solo lo suyo" do
    get "/api/v1/dashboard", headers: headers_for(@comun)

    assert_response :ok
    body = response.parsed_body
    assert_equal 1000, BigDecimal(body["income"])
    assert_equal 100, BigDecimal(body["consumption"])
    assert_equal [ "comun" ], body["incomes"].map { |i| i["user"] }
  end

  test "el dashboard del admin suma lo de todos" do
    get "/api/v1/dashboard", headers: headers_for(@admin)

    assert_response :ok
    body = response.parsed_body
    assert_equal 1500, BigDecimal(body["income"])
    assert_equal 300, BigDecimal(body["consumption"])
  end

  test "listar usuarios sin token da 401" do
    get "/api/v1/users"

    assert_response :unauthorized
  end

  test "listar usuarios como usuario comun da 403" do
    get "/api/v1/users", headers: headers_for(@comun)

    assert_response :forbidden
    assert_equal [ { "field" => "base", "message" => "Acceso denegado" } ], response.parsed_body["errors"]
  end

  test "listar usuarios como admin devuelve todos sin datos sensibles" do
    get "/api/v1/users", headers: headers_for(@admin)

    assert_response :ok
    usuarios = response.parsed_body
    assert_equal %w[comun jefa otro], usuarios.map { |u| u["user"] }.sort
    assert_not usuarios.first.key?("auth_token")
    assert_not usuarios.first.key?("password_digest")
  end
end
