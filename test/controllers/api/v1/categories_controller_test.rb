require "test_helper"

class Api::V1::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    familia = FamilyGroup.create!(name: "Familia de prueba")
    @familia = familia
    @user = User.create!(user: "tester", password: "password123", family_group: familia)
    @headers = { "Authorization" => "Bearer #{AuthToken.encode(@user)}" }
    @admin = User.create!(user: "jefa", password: "password123", family_group: familia, admin: true)
    @admin_headers = { "Authorization" => "Bearer #{AuthToken.encode(@admin)}" }
  end

  test "sin header de autorizacion da 401" do
    get "/api/v1/categories"

    assert_response :unauthorized
  end

  test "con header de autorizacion vacio da 401" do
    get "/api/v1/categories", headers: { "Authorization" => "" }

    assert_response :unauthorized
  end

  test "con token invalido da 401" do
    get "/api/v1/categories", headers: { "Authorization" => "Bearer tokenfalso" }

    assert_response :unauthorized
  end

  test "con token valido devuelve las categorias ordenadas por nombre" do
    Category.create!(name: "Transporte")
    Category.create!(name: "Comida")

    get "/api/v1/categories", headers: @headers

    assert_response :ok
    assert_equal %w[Comida Transporte], response.parsed_body.map { |c| c["name"] }
  end


  test "un usuario comun no puede crear ni editar categorias: 403" do
    categoria = Category.create!(name: "Comida")

    assert_no_difference "Category.count" do
      post "/api/v1/categories", params: { name: "Nueva" }, headers: @headers, as: :json
    end
    assert_response :forbidden

    patch "/api/v1/categories/#{categoria.id}", params: { name: "Otra" }, headers: @headers, as: :json
    assert_response :forbidden
    assert_equal "Comida", categoria.reload.name
  end

  test "sin token, crear una categoria da 401" do
    post "/api/v1/categories", params: { name: "Nueva" }, as: :json

    assert_response :unauthorized
  end

  test "el admin crea una categoria y una subcategoria" do
    assert_difference "Category.count", 2 do
      post "/api/v1/categories", params: { name: "Tarjetas" }, headers: @admin_headers, as: :json
      assert_response :created
      padre_id = response.parsed_body["id"]
      assert_nil response.parsed_body["parent_id"]

      post "/api/v1/categories", params: { name: "Visa", parent_id: padre_id },
                                 headers: @admin_headers, as: :json
      assert_response :created
      assert_equal padre_id, response.parsed_body["parent_id"]
    end
  end

  test "crear sin nombre da 422 con el campo name" do
    post "/api/v1/categories", params: { name: "" }, headers: @admin_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal "name", response.parsed_body["errors"].first["field"]
  end

  test "crear con un padre que no existe da 422 con el campo parent_id" do
    post "/api/v1/categories", params: { name: "Huerfana", parent_id: 999_999 },
                               headers: @admin_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal "parent_id", response.parsed_body["errors"].first["field"]
  end

  test "el admin edita el nombre de una categoria" do
    categoria = Category.create!(name: "Comida")

    patch "/api/v1/categories/#{categoria.id}", params: { name: "Alimentos" },
                                               headers: @admin_headers, as: :json

    assert_response :ok
    assert_equal "Alimentos", response.parsed_body["name"]
    assert_equal "Alimentos", categoria.reload.name
  end

  test "una categoria no puede ser su propio padre: 422" do
    categoria = Category.create!(name: "Comida")

    patch "/api/v1/categories/#{categoria.id}", params: { parent_id: categoria.id },
                                               headers: @admin_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal "parent_id", response.parsed_body["errors"].first["field"]
  end

  test "editar una categoria que no existe da 404" do
    patch "/api/v1/categories/999999", params: { name: "X" }, headers: @admin_headers, as: :json

    assert_response :not_found
  end

  test "el admin borra una categoria sin uso y responde 204" do
    categoria = Category.create!(name: "Sobrante")

    assert_difference "Category.count", -1 do
      delete "/api/v1/categories/#{categoria.id}", headers: @admin_headers
    end

    assert_response :no_content
  end

  test "un usuario comun no puede borrar categorias: 403" do
    categoria = Category.create!(name: "Comida")

    assert_no_difference "Category.count" do
      delete "/api/v1/categories/#{categoria.id}", headers: @headers
    end

    assert_response :forbidden
  end

  test "no se borra una categoria con gastos: 422 y no se pierde nada" do
    categoria = Category.create!(name: "Comida")
    Expense.create!(user: @user, category: categoria, amount: 100, date: Date.current)

    assert_no_difference [ "Category.count", "Expense.count" ] do
      delete "/api/v1/categories/#{categoria.id}", headers: @admin_headers
    end

    assert_response :unprocessable_entity
    assert_equal "base", response.parsed_body["errors"].first["field"]
  end

  test "no se borra una categoria con subcategorias: 422" do
    padre = Category.create!(name: "Tarjetas")
    Category.create!(name: "Visa", parent: padre)

    assert_no_difference "Category.count" do
      delete "/api/v1/categories/#{padre.id}", headers: @admin_headers
    end

    assert_response :unprocessable_entity
  end

  test "no se borra una categoria con gastos fijos: 422" do
    categoria = Category.create!(name: "Comida")
    ShoppingListItem.create!(family_group: @user.family_group, category: categoria, name: "Arroz",
                             period: "2026-11", quantity: 1, estimated_unit_price: 10)

    assert_no_difference "Category.count" do
      delete "/api/v1/categories/#{categoria.id}", headers: @admin_headers
    end

    assert_response :unprocessable_entity
  end

  test "borrar una categoria que no existe da 404" do
    delete "/api/v1/categories/999999", headers: @admin_headers

    assert_response :not_found
  end

  # --- Estimado vs real de una categoría

  def comparison(categoria, params = {}, headers: @headers)
    get "/api/v1/categories/#{categoria.id}/comparison", params: params, headers: headers
    response.parsed_body
  end

  def decimal(valor)
    BigDecimal(valor.to_s)
  end

  def gasto_con_items(user, categoria, fecha, items)
    Expense.create!(user: user, category: categoria, date: fecha,
                    expense_items_attributes: items.map { |name, quantity, unit_price|
                      { name: name, quantity: quantity, unit_price: unit_price, unit: "unidad" }
                    })
  end

  test "comparison sin token da 401" do
    get "/api/v1/categories/1/comparison"

    assert_response :unauthorized
  end

  test "comparison de una categoria que no existe da 404" do
    get "/api/v1/categories/999999/comparison", headers: @headers

    assert_response :not_found
  end

  test "comparison con un periodo mal formado da 422 en period" do
    categoria = Category.create!(name: "Comida")

    comparison(categoria, { period: "septiembre" })

    assert_response :unprocessable_entity
    assert_equal "period", response.parsed_body["errors"].first["field"]
  end

  test "comparison por producto compara lo estimado con lo real y marca los no planificados y no comprados" do
    comida = Category.create!(name: "Comida")
    ShoppingListItem.create!(family_group: @familia, category: comida, name: "Arroz",
                             period: "2026-09", quantity: 2, estimated_unit_price: 100)
    ShoppingListItem.create!(family_group: @familia, category: comida, name: "Leche",
                             period: "2026-09", quantity: 1, estimated_unit_price: 50)
    gasto_con_items(@user, comida, Date.new(2026, 9, 5), [ [ " arroz ", 3, 90 ], [ "Chicle", 1, 20 ] ])

    body = comparison(comida, { period: "2026-09" })
    filas = body["items"].index_by { |fila| fila["name"] }

    assert_response :ok
    assert_equal comida.id, body["category"]["id"]
    assert_equal "2026-09", body["period"]
    assert_equal [], body["subcategories"]
    assert_equal 250, decimal(body["planned_total"])
    assert_equal 290, decimal(body["real_total"])

    arroz = filas["Arroz"]
    assert_equal "bought", arroz["status"]
    assert_equal 2, decimal(arroz["planned_quantity"])
    assert_equal 200, decimal(arroz["planned_total"])
    assert_equal 3, decimal(arroz["real_quantity"])
    assert_equal 270, decimal(arroz["real_total"])
    assert_equal 90, decimal(arroz["real_unit_price"])

    assert_equal "unplanned", filas["Chicle"]["status"]
    assert_equal "not_bought", filas["Leche"]["status"]
    assert_equal 0, decimal(filas["Leche"]["real_total"])
  end

  test "comparison por subcategoria trae lo estimado, lo real y si se paso" do
    comida = Category.create!(name: "Comida")
    verduras = Category.create!(name: "Verduras", parent: comida)
    carnes = Category.create!(name: "Carnes", parent: comida)
    ShoppingListItem.create!(family_group: @familia, category: verduras, name: "Tomate",
                             period: "2026-09", quantity: 1, estimated_unit_price: 100)
    Expense.create!(user: @user, category: verduras, amount: 150, date: Date.new(2026, 9, 3))
    Expense.create!(user: @user, category: carnes, amount: 40, date: Date.new(2026, 9, 4))
    Expense.create!(user: @user, category: verduras, amount: 999, date: Date.new(2026, 8, 30))

    body = comparison(comida, { period: "2026-09" })
    carnes_fila, verduras_fila = body["subcategories"]

    assert_response :ok
    assert_equal [], body["items"]
    assert_equal "Carnes", carnes_fila["category"]["name"]
    assert_equal 40, decimal(carnes_fila["real"])
    assert_equal false, carnes_fila["over_budget"]
    assert_equal "Verduras", verduras_fila["category"]["name"]
    assert_equal 100, decimal(verduras_fila["planned"])
    assert_equal 150, decimal(verduras_fila["real"])
    assert_equal true, verduras_fila["over_budget"]
    assert_equal 100, decimal(body["planned_total"])
    assert_equal 190, decimal(body["real_total"])
  end

  test "comparison sin periodo usa el mes en curso" do
    travel_to Date.new(2026, 9, 15)
    comida = Category.create!(name: "Comida")

    body = comparison(comida)

    assert_response :ok
    assert_equal "2026-09", body["period"]
  end

  test "comparison cuenta solo los gastos del usuario, pero lo estimado es del grupo familiar" do
    comida = Category.create!(name: "Comida")
    Expense.create!(user: @user, category: comida, amount: 100, date: Date.new(2026, 9, 3))
    Expense.create!(user: @admin, category: comida, amount: 500, date: Date.new(2026, 9, 4))
    ShoppingListItem.create!(family_group: @familia, category: comida, name: "Arroz",
                             period: "2026-09", quantity: 1, estimated_unit_price: 70)
    otra_familia = FamilyGroup.create!(name: "Otra familia")
    ShoppingListItem.create!(family_group: otra_familia, category: comida, name: "Ajeno",
                             period: "2026-09", quantity: 1, estimated_unit_price: 999)

    usuario = comparison(comida, { period: "2026-09" })
    admin = comparison(comida, { period: "2026-09" }, headers: @admin_headers)

    assert_equal 100, decimal(usuario["real_total"])
    assert_equal 70, decimal(usuario["planned_total"])
    assert_equal 600, decimal(admin["real_total"])
    assert_equal 1069, decimal(admin["planned_total"])
  end
end
