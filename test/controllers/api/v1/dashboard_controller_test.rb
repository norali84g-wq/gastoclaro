require "test_helper"

class Api::V1::DashboardControllerTest < ActionDispatch::IntegrationTest
  HOY = Date.new(2026, 9, 15)

  setup do
    @familia = FamilyGroup.create!(name: "Familia de prueba", savings_percentage: 20)
    @user = User.create!(user: "tester", password: "password123", family_group: @familia)
    @pareja = User.create!(user: "pareja", password: "password123", family_group: @familia)
    @headers = { "Authorization" => "Bearer #{@user.auth_token}" }

    @otra_familia = FamilyGroup.create!(name: "Otra familia")
    @otro_user = User.create!(user: "otro", password: "password123", family_group: @otra_familia)

    @comida = Category.create!(name: "Comida")
    @transporte = Category.create!(name: "Transporte")

    travel_to HOY
  end

  def dashboard
    get "/api/v1/dashboard", headers: @headers
    response.parsed_body
  end

  def decimal(valor)
    BigDecimal(valor.to_s)
  end

  test "sin token da 401" do
    get "/api/v1/dashboard"

    assert_response :unauthorized
  end

  test "sin datos devuelve todo en cero" do
    body = dashboard

    assert_response :ok
    assert_equal "2026-09", body["periodo"]
    assert_equal 0, decimal(body["ingreso"])
    assert_equal 0, decimal(body["consumo"])
    assert_equal 0, decimal(body["ahorro"])
    assert_equal [], body["ingresos"]
    assert_equal [], body["consumo_por_categoria"]
  end

  test "suma ingresos y gastos del mes de toda la familia y calcula el ahorro" do
    Income.create!(user: @user, amount: 1000, date: Date.new(2026, 9, 1))
    Income.create!(user: @pareja, amount: 500, date: Date.new(2026, 9, 10))
    Expense.create!(user: @user, category: @comida, amount: 300, date: Date.new(2026, 9, 5))
    Expense.create!(user: @pareja, category: @comida, amount: 100, date: Date.new(2026, 9, 6))

    body = dashboard

    assert_response :ok
    assert_equal 1500, decimal(body["ingreso"])
    assert_equal 400, decimal(body["consumo"])
    assert_equal 1100, decimal(body["ahorro"])
    assert_equal 20, body["meta_ahorro_porcentaje"]
  end

  test "deja afuera otros meses y otras familias" do
    Income.create!(user: @user, amount: 1000, date: Date.new(2026, 9, 1))
    Income.create!(user: @user, amount: 9999, date: Date.new(2026, 8, 31))
    Income.create!(user: @otro_user, amount: 8888, date: Date.new(2026, 9, 2))
    Expense.create!(user: @user, category: @comida, amount: 200, date: Date.new(2026, 9, 3))
    Expense.create!(user: @user, category: @comida, amount: 7777, date: Date.new(2026, 10, 1))
    Expense.create!(user: @otro_user, category: @comida, amount: 6666, date: Date.new(2026, 9, 3))

    body = dashboard

    assert_equal 1000, decimal(body["ingreso"])
    assert_equal 200, decimal(body["consumo"])
    assert_equal [ "tester" ], body["ingresos"].map { |i| i["usuario"] }
  end

  test "agrupa el consumo del mes por categoria" do
    Expense.create!(user: @user, category: @comida, amount: 300, date: Date.new(2026, 9, 5))
    Expense.create!(user: @pareja, category: @comida, amount: 100, date: Date.new(2026, 9, 6))
    Expense.create!(user: @user, category: @transporte, amount: 50, date: Date.new(2026, 9, 7))

    por_categoria = dashboard["consumo_por_categoria"].to_h { |c| [ c["categoria"], decimal(c["total"]) ] }

    assert_equal({ "Comida" => 400, "Transporte" => 50 }, por_categoria)
  end

  test "ahorro_mensual trae los ultimos 6 meses en orden con el acumulado" do
    Income.create!(user: @user, amount: 500, date: Date.new(2026, 8, 10))
    Expense.create!(user: @user, category: @comida, amount: 100, date: Date.new(2026, 8, 12))
    Income.create!(user: @user, amount: 1000, date: Date.new(2026, 9, 1))
    Expense.create!(user: @user, category: @comida, amount: 400, date: Date.new(2026, 9, 5))

    meses = dashboard["ahorro_mensual"]

    assert_equal %w[2026-04 2026-05 2026-06 2026-07 2026-08 2026-09], meses.map { |m| m["mes"] }
    agosto, septiembre = meses.last(2)
    assert_equal 400, decimal(agosto["ahorro"])
    assert_equal 400, decimal(agosto["acumulado"])
    assert_equal 600, decimal(septiembre["ahorro"])
    assert_equal 1000, decimal(septiembre["acumulado"])
  end
end
