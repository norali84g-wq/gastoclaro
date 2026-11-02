require "test_helper"

class Api::V1::ExpensesUpdateDestroyTest < ActionDispatch::IntegrationTest
  setup do
    @familia = FamilyGroup.create!(name: "Familia de prueba")
    @user = User.create!(user: "tester", password: "password123", family_group: @familia)
    @admin = User.create!(user: "jefa", password: "password123", family_group: @familia, admin: true)
    @categoria = Category.create!(name: "Supermercado")
    @gasto = Expense.create!(user: @user, category: @categoria, date: "2026-09-29", amount: 500, description: "original")

    @otra_familia = FamilyGroup.create!(name: "Otra familia")
    @otro_user = User.create!(user: "otro", password: "password123", family_group: @otra_familia)
    @gasto_ajeno = Expense.create!(user: @otro_user, category: @categoria, date: "2026-09-29", amount: 777, description: "ajeno")
  end

  def headers_for(user)
    { "Authorization" => "Bearer #{AuthToken.encode(user)}" }
  end

  def gasto_con_items
    gasto = Expense.new(user: @user, category: @categoria, date: "2026-09-29", description: "con items")
    gasto.expense_items.build(name: "Leche", quantity: 2, unit_price: 100)
    gasto.expense_items.build(name: "Pan", quantity: 1, unit_price: 50)
    gasto.save!
    gasto
  end

  # --- PATCH /expenses/:id ---

  test "update sin token da 401" do
    patch "/api/v1/expenses/#{@gasto.id}", params: { description: "nuevo" }, as: :json

    assert_response :unauthorized
  end

  test "update cambia solo lo que se envia" do
    patch "/api/v1/expenses/#{@gasto.id}", params: { description: "Compra del sabado" },
                                           headers: headers_for(@user), as: :json

    assert_response :ok
    assert_equal "Compra del sabado", response.parsed_body["description"]
    assert_equal 500, BigDecimal(response.parsed_body["amount"])
    assert_equal "Compra del sabado", @gasto.reload.description
  end

  test "update de un gasto de otro usuario da 404 y no lo modifica" do
    patch "/api/v1/expenses/#{@gasto_ajeno.id}", params: { description: "hackeado" },
                                                 headers: headers_for(@user), as: :json

    assert_response :not_found
    assert_equal [ { "field" => "base", "message" => "No encontrado" } ], response.parsed_body["errors"]
    assert_equal "ajeno", @gasto_ajeno.reload.description
  end

  test "update de un gasto que no existe da 404" do
    patch "/api/v1/expenses/0", params: { description: "x" }, headers: headers_for(@user), as: :json

    assert_response :not_found
  end

  test "el admin puede editar el gasto de otro usuario" do
    patch "/api/v1/expenses/#{@gasto_ajeno.id}", params: { description: "editado por admin" },
                                                 headers: headers_for(@admin), as: :json

    assert_response :ok
    assert_equal "editado por admin", @gasto_ajeno.reload.description
    assert_equal @otro_user.id, @gasto_ajeno.user_id
  end

  test "update ignora user_id enviado: el gasto no cambia de dueno" do
    patch "/api/v1/expenses/#{@gasto.id}", params: { description: "x", user_id: @otro_user.id },
                                           headers: headers_for(@user), as: :json

    assert_response :ok
    assert_equal @user.id, @gasto.reload.user_id
  end

  test "update con monto invalido da 422 y no modifica el gasto" do
    patch "/api/v1/expenses/#{@gasto.id}", params: { amount: 0 }, headers: headers_for(@user), as: :json

    assert_response :unprocessable_entity
    assert_equal [ { "field" => "amount", "message" => "debe ser mayor a 0" } ], response.parsed_body["errors"]
    assert_equal 500, @gasto.reload.amount
  end

  test "update con purchase_channel invalido da 422" do
    patch "/api/v1/expenses/#{@gasto.id}", params: { purchase_channel: "drone" },
                                           headers: headers_for(@user), as: :json

    assert_response :unprocessable_entity
    assert_equal [ { "field" => "purchase_channel", "message" => "no es válido" } ], response.parsed_body["errors"]
  end

  test "update con una categoria que no existe da 422" do
    patch "/api/v1/expenses/#{@gasto.id}", params: { category_id: 0 }, headers: headers_for(@user), as: :json

    assert_response :unprocessable_entity
    assert_equal "category_id", response.parsed_body["errors"].first["field"]
  end

  test "update edita y borra items y recalcula el amount" do
    gasto = gasto_con_items
    leche, pan = gasto.expense_items.order(:id).to_a
    assert_equal 250, gasto.amount

    patch "/api/v1/expenses/#{gasto.id}",
          params: { expense_items_attributes: [
            { id: leche.id, name: "Leche", quantity: 3 },
            { id: pan.id, _destroy: true }
          ] },
          headers: headers_for(@user), as: :json

    assert_response :ok
    assert_equal 300, BigDecimal(response.parsed_body["amount"])
    assert_equal [ "Leche" ], response.parsed_body["expense_items"].map { |i| i["name"] }
    assert_equal 3, response.parsed_body["expense_items"].first["quantity"]
    assert_equal 1, gasto.reload.expense_items.count
  end

  test "update agrega un item nuevo y recalcula el amount" do
    gasto = gasto_con_items

    patch "/api/v1/expenses/#{gasto.id}",
          params: { expense_items_attributes: [ { name: "Queso", quantity: 1, unit_price: 200 } ] },
          headers: headers_for(@user), as: :json

    assert_response :ok
    assert_equal 450, BigDecimal(response.parsed_body["amount"])
    assert_equal 3, response.parsed_body["expense_items"].size
  end

  test "update que borra todos los items conserva el amount anterior" do
    gasto = gasto_con_items
    ids = gasto.expense_items.pluck(:id)

    patch "/api/v1/expenses/#{gasto.id}",
          params: { expense_items_attributes: ids.map { |id| { id: id, _destroy: true } } },
          headers: headers_for(@user), as: :json

    assert_response :ok
    assert_equal 250, BigDecimal(response.parsed_body["amount"])
    assert_empty response.parsed_body["expense_items"]
  end

  test "update con el id de un item de otro gasto da 404 y no lo toca" do
    ajeno = Expense.new(user: @otro_user, category: @categoria, date: "2026-09-29")
    ajeno.expense_items.build(name: "Ajeno", quantity: 1, unit_price: 10)
    ajeno.save!
    item_ajeno = ajeno.expense_items.first

    patch "/api/v1/expenses/#{@gasto.id}",
          params: { expense_items_attributes: [ { id: item_ajeno.id, name: "Robado" } ] },
          headers: headers_for(@user), as: :json

    assert_response :not_found
    assert_equal "Ajeno", item_ajeno.reload.name
  end

  # --- DELETE /expenses/:id ---

  test "destroy sin token da 401" do
    assert_no_difference "Expense.count" do
      delete "/api/v1/expenses/#{@gasto.id}"
    end

    assert_response :unauthorized
  end

  test "destroy borra el gasto y sus items y responde 204 sin cuerpo" do
    gasto = gasto_con_items

    assert_difference "Expense.count", -1 do
      assert_difference "ExpenseItem.count", -2 do
        delete "/api/v1/expenses/#{gasto.id}", headers: headers_for(@user)
      end
    end

    assert_response :no_content
    assert_empty response.body
  end

  test "destroy de un gasto de otro usuario da 404 y no lo borra" do
    assert_no_difference "Expense.count" do
      delete "/api/v1/expenses/#{@gasto_ajeno.id}", headers: headers_for(@user)
    end

    assert_response :not_found
  end

  test "el admin puede borrar el gasto de otro usuario" do
    assert_difference "Expense.count", -1 do
      delete "/api/v1/expenses/#{@gasto_ajeno.id}", headers: headers_for(@admin)
    end

    assert_response :no_content
  end

  test "destroy de un gasto que no existe da 404" do
    delete "/api/v1/expenses/0", headers: headers_for(@user)

    assert_response :not_found
  end
end
