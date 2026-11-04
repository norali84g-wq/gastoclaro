require "test_helper"

class Api::V1::StatisticsControllerTest < ActionDispatch::IntegrationTest
  HOY = Date.new(2026, 9, 15)

  setup do
    @familia = FamilyGroup.create!(name: "Familia de prueba")
    @user = User.create!(user: "tester", password: "password123", family_group: @familia)
    @headers = { "Authorization" => "Bearer #{AuthToken.encode(@user)}" }
    @admin = User.create!(user: "jefa", password: "password123", family_group: @familia, admin: true)
    @admin_headers = { "Authorization" => "Bearer #{AuthToken.encode(@admin)}" }
    @otra_familia = FamilyGroup.create!(name: "Otra familia")
    @otro = User.create!(user: "otro", password: "password123", family_group: @otra_familia)

    @comida = Category.create!(name: "Comida")
    @verduras = Category.create!(name: "Verduras", parent: @comida)
    @carnes = Category.create!(name: "Carnes", parent: @comida)
    @transporte = Category.create!(name: "Transporte")
    @coto = Vendor.create!(name: "Coto")

    travel_to HOY
  end

  def statistics(params = {}, headers: @headers)
    get "/api/v1/statistics", params: params, headers: headers
    response.parsed_body
  end

  def decimal(valor)
    BigDecimal(valor.to_s)
  end

  def gasto_con_items(user, categoria, fecha, items, vendor: nil)
    Expense.create!(user: user, category: categoria, date: fecha, vendor: vendor,
                    expense_items_attributes: items.map { |name, quantity, unit_price|
                      { name: name, quantity: quantity, unit_price: unit_price, unit: "unidad" }
                    })
  end

  def mes(body, periodo)
    body["months"].find { |fila| fila["month"] == periodo }
  end

  test "sin token da 401" do
    get "/api/v1/statistics"

    assert_response :unauthorized
  end

  test "un anio mal formado o futuro da 422 en year" do
    [ "abc", "1999", "2027" ].each do |year|
      get "/api/v1/statistics", params: { year: year }, headers: @headers

      assert_response :unprocessable_entity
      assert_equal "year", response.parsed_body["errors"].first["field"]
    end
  end

  test "un mes fuera de rango da 422 en month" do
    [ "0", "13", "marzo" ].each do |month|
      get "/api/v1/statistics", params: { month: month }, headers: @headers

      assert_response :unprocessable_entity
      assert_equal "month", response.parsed_body["errors"].first["field"]
    end
  end

  test "con year y month mal formados da un solo error y no falla" do
    get "/api/v1/statistics", params: { year: "abc", month: "99" }, headers: @headers

    assert_response :unprocessable_entity
    assert_equal 1, response.parsed_body["errors"].size
  end

  test "sin datos devuelve los meses del anio en curso en cero" do
    body = statistics

    assert_response :ok
    assert_equal 2026, body["year"]
    assert_nil body["month"]
    assert_equal [ 2026 ], body["available_years"]
    esperados = (1..9).map { |m| format("2026-%02d", m) }
    assert_equal esperados, body["months"].map { |fila| fila["month"] }
    assert(body["months"].all? { |fila| decimal(fila["savings"]).zero? })
    assert(body["by_category"].all? { |grupo| decimal(grupo["total"]).zero? })
    assert_equal 0, decimal(body["unplanned"]["total"])
    assert_equal [], body["unplanned"]["items"]
  end

  test "cada mes trae ingreso, consumo y ahorro" do
    Income.create!(user: @user, amount: 1000, date: Date.new(2026, 8, 10))
    Expense.create!(user: @user, category: @transporte, amount: 300, date: Date.new(2026, 8, 12))
    Income.create!(user: @user, amount: 500, date: Date.new(2026, 9, 1))
    Expense.create!(user: @user, category: @transporte, amount: 700, date: Date.new(2026, 9, 5))

    body = statistics
    agosto = mes(body, "2026-08")
    septiembre = mes(body, "2026-09")

    assert_equal 1000, decimal(agosto["income"])
    assert_equal 300, decimal(agosto["consumption"])
    assert_equal 700, decimal(agosto["savings"])
    assert_equal(-200, decimal(septiembre["savings"]))
  end

  test "el consumo por categoria agrupa las hojas bajo su principal, con su parte y si se pasaron" do
    Expense.create!(user: @user, category: @verduras, amount: 150, date: Date.new(2026, 9, 3))
    Expense.create!(user: @user, category: @carnes, amount: 50, date: Date.new(2026, 9, 4))
    Expense.create!(user: @user, category: @transporte, amount: 100, date: Date.new(2026, 9, 5))
    ShoppingListItem.create!(family_group: @familia, category: @verduras, name: "Tomate",
                             period: "2026-09", quantity: 1, estimated_unit_price: 100)

    grupos = statistics["by_category"].reject { |grupo| decimal(grupo["total"]).zero? }
    comida, transporte = grupos
    verduras, carnes = comida["subcategories"]

    assert_equal [ "Comida", "Transporte" ], grupos.map { |grupo| grupo["category"]["name"] }
    assert_equal 200, decimal(comida["total"])
    assert_in_delta 66.7, comida["percentage"], 0.01
    assert_equal 100, decimal(transporte["total"])
    assert_in_delta 33.3, transporte["percentage"], 0.01
    assert_equal "Verduras", verduras["category"]["name"]
    assert_equal 150, decimal(verduras["real"])
    assert_equal 100, decimal(verduras["planned"])
    assert_equal true, verduras["over_budget"]
    assert_in_delta 50.0, verduras["percentage"], 0.01
    assert_equal "Carnes", carnes["category"]["name"]
    assert_equal false, carnes["over_budget"]
  end

  test "el gasto hormiga son los productos comprados que no estaban planificados" do
    ShoppingListItem.create!(family_group: @familia, category: @transporte, name: "SUBE",
                             period: "2026-09", quantity: 1, estimated_unit_price: 50)
    gasto_con_items(@user, @transporte, Date.new(2026, 9, 5),
                    [ [ "sube", 1, 50 ], [ "Cafe", 2, 30 ] ], vendor: @coto)
    gasto_con_items(@user, @transporte, Date.new(2026, 9, 6), [ [ "Chicle", 1, 10 ] ])
    # Una categoria con subcategorias no cuenta: solo se miran las categorias sin subcategorias.
    gasto_con_items(@user, @comida, Date.new(2026, 9, 7), [ [ "Pan", 1, 500 ] ])

    body = statistics
    hormiga = body["unplanned"]

    assert_equal 70, decimal(hormiga["total"])
    assert_equal [ "Coto", nil ], hormiga["by_vendor"].map { |fila| fila["vendor"] }
    assert_equal [ 60, 10 ], hormiga["by_vendor"].map { |fila| decimal(fila["total"]) }
    assert_equal [ "Cafe", "Chicle" ], hormiga["items"].map { |item| item["name"] }
    assert_equal 70, decimal(mes(body, "2026-09")["unplanned"])
  end

  test "con month solo cuenta ese mes, pero siempre trae todos los meses del anio" do
    Expense.create!(user: @user, category: @transporte, amount: 300, date: Date.new(2026, 8, 12))
    Expense.create!(user: @user, category: @transporte, amount: 700, date: Date.new(2026, 9, 5))

    body = statistics({ month: "8" })
    transporte = body["by_category"].find { |grupo| grupo["category"]["name"] == "Transporte" }

    assert_equal 8, body["month"]
    assert_equal 9, body["months"].size
    assert_equal 300, decimal(transporte["total"])
    assert_in_delta 100.0, transporte["percentage"], 0.01
  end

  test "available_years llega hasta el primer movimiento y un anio anterior trae sus doce meses" do
    Expense.create!(user: @user, category: @transporte, amount: 100, date: Date.new(2025, 12, 10))

    body = statistics({ year: "2025" })

    assert_equal [ 2026, 2025 ], body["available_years"]
    assert_equal 12, body["months"].size
    assert_equal 100, decimal(mes(body, "2025-12")["consumption"])
  end

  test "cada usuario ve solo lo suyo y el admin ve todo" do
    Expense.create!(user: @user, category: @transporte, amount: 100, date: Date.new(2026, 9, 3))
    Expense.create!(user: @otro, category: @transporte, amount: 999, date: Date.new(2026, 9, 4))
    ShoppingListItem.create!(family_group: @otra_familia, category: @transporte, name: "Ajeno",
                             period: "2026-09", quantity: 1, estimated_unit_price: 5)

    usuario = statistics
    admin = statistics({}, headers: @admin_headers)

    assert_equal 100, decimal(mes(usuario, "2026-09")["consumption"])
    assert_equal 1099, decimal(mes(admin, "2026-09")["consumption"])
  end
end
