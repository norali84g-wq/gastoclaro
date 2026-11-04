require "test_helper"

class Api::V1::ShoppingListItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @familia = FamilyGroup.create!(name: "Familia de prueba")
    @user = User.create!(user: "tester", password: "password123", family_group: @familia)
    @admin = User.create!(user: "jefa", password: "password123", family_group: @familia, admin: true)
    @comida = Category.create!(name: "Comida")
    @servicios = Category.create!(name: "Servicios")
    @item = ShoppingListItem.create!(family_group: @familia, category: @comida, name: "Arroz",
                                     period: "2026-11", quantity: 2, estimated_unit_price: 1500)
    @item_otro_mes = ShoppingListItem.create!(family_group: @familia, category: @servicios, name: "Luz",
                                              period: "2026-12", quantity: 1, estimated_unit_price: 9000)

    @otra_familia = FamilyGroup.create!(name: "Otra familia")
    @otro_user = User.create!(user: "otro", password: "password123", family_group: @otra_familia)
    @item_ajeno = ShoppingListItem.create!(family_group: @otra_familia, category: @comida, name: "Ajeno",
                                           period: "2026-11", quantity: 1, estimated_unit_price: 100)
  end

  def headers_for(user)
    { "Authorization" => "Bearer #{AuthToken.encode(user)}" }
  end

  test "index sin token da 401" do
    get "/api/v1/shopping_list_items"

    assert_response :unauthorized
  end

  test "index devuelve solo los items del grupo familiar, con categoria y subtotal calculado" do
    get "/api/v1/shopping_list_items", headers: headers_for(@user)

    assert_response :ok
    items = response.parsed_body
    assert_equal %w[Arroz Luz], items.map { |i| i["name"] }
    arroz = items.first
    assert_equal "2026-11", arroz["period"]
    assert_equal BigDecimal("3000"), BigDecimal(arroz["subtotal"])
    assert_equal({ "id" => @comida.id, "name" => "Comida" }, arroz["category"])
  end

  test "index filtra por periodo" do
    get "/api/v1/shopping_list_items", params: { period: "2026-12" }, headers: headers_for(@user)

    assert_equal [ "Luz" ], response.parsed_body.map { |i| i["name"] }
  end

  test "el admin ve los items de todos los grupos" do
    get "/api/v1/shopping_list_items", headers: headers_for(@admin)

    assert_equal %w[Ajeno Arroz Luz], response.parsed_body.map { |i| i["name"] }.sort
  end

  test "create con datos validos da 201 y queda en el grupo del usuario" do
    assert_difference "ShoppingListItem.count", 1 do
      post "/api/v1/shopping_list_items",
           params: { name: "Fideos", period: "2026-11", quantity: 3, estimated_unit_price: 800,
                     category_id: @comida.id },
           headers: headers_for(@user), as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "Fideos", body["name"]
    assert_equal BigDecimal("2400"), BigDecimal(body["subtotal"])
    assert_equal @familia.id, ShoppingListItem.find(body["id"]).family_group_id
  end

  test "create ignora un family_group_id enviado" do
    post "/api/v1/shopping_list_items",
         params: { name: "Fideos", period: "2026-11", quantity: 1, estimated_unit_price: 800,
                   category_id: @comida.id, family_group_id: @otra_familia.id },
         headers: headers_for(@user), as: :json

    assert_response :created
    assert_equal @familia.id, ShoppingListItem.find(response.parsed_body["id"]).family_group_id
  end

  test "create con datos invalidos da 422 con el campo de cada error" do
    post "/api/v1/shopping_list_items",
         params: { name: "", period: "noviembre", quantity: 0, estimated_unit_price: -1 },
         headers: headers_for(@user), as: :json

    assert_response :unprocessable_entity
    campos = response.parsed_body["errors"].map { |e| e["field"] }
    assert_includes campos, "name"
    assert_includes campos, "period"
    assert_includes campos, "quantity"
    assert_includes campos, "estimated_unit_price"
    assert_includes campos, "category_id"
  end

  test "update cambia solo lo que se envia" do
    patch "/api/v1/shopping_list_items/#{@item.id}",
          params: { quantity: 5 }, headers: headers_for(@user), as: :json

    assert_response :ok
    assert_equal BigDecimal("7500"), BigDecimal(response.parsed_body["subtotal"])
    assert_equal "Arroz", @item.reload.name
  end

  test "update de un item de otro grupo da 404 y no lo cambia" do
    patch "/api/v1/shopping_list_items/#{@item_ajeno.id}",
          params: { name: "Hackeado" }, headers: headers_for(@user), as: :json

    assert_response :not_found
    assert_equal "Ajeno", @item_ajeno.reload.name
  end

  test "destroy borra el item y responde 204" do
    assert_difference "ShoppingListItem.count", -1 do
      delete "/api/v1/shopping_list_items/#{@item.id}", headers: headers_for(@user)
    end

    assert_response :no_content
  end

  test "destroy de un item de otro grupo da 404 y no lo borra" do
    assert_no_difference "ShoppingListItem.count" do
      delete "/api/v1/shopping_list_items/#{@item_ajeno.id}", headers: headers_for(@user)
    end

    assert_response :not_found
  end
end
