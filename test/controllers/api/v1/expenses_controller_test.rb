require "test_helper"

class Api::V1::ExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @familia = FamilyGroup.create!(name: "Familia de prueba")
    @user = User.create!(user: "tester", password: "password123", family_group: @familia)
    @headers = { "Authorization" => "Bearer #{@user.auth_token}" }
    @categoria = Category.create!(name: "Supermercado")

    @otra_familia = FamilyGroup.create!(name: "Otra familia")
    @otro_user = User.create!(user: "otro", password: "password123", family_group: @otra_familia)
  end

  test "index sin token da 401" do
    get "/api/v1/expenses"

    assert_response :unauthorized
  end

  test "index devuelve solo los gastos de la familia del usuario, con sus items" do
    propio = Expense.new(user: @user, category: @categoria, date: Date.today, description: "propio")
    propio.expense_items.build(name: "Leche", quantity: 2, unit_price: 100)
    propio.save!
    Expense.create!(user: @otro_user, category: @categoria, date: Date.today, amount: 777, description: "ajeno")

    get "/api/v1/expenses", headers: @headers

    assert_response :ok
    gastos = response.parsed_body
    assert_equal [ "propio" ], gastos.map { |g| g["description"] }
    assert_equal [ "Leche" ], gastos.first["expense_items"].map { |i| i["name"] }
  end

  test "create sin token da 401" do
    assert_no_difference "Expense.count" do
      post "/api/v1/expenses", params: { amount: 10, date: "2026-09-29", category_id: @categoria.id }, as: :json
    end

    assert_response :unauthorized
  end

  test "create con items calcula el amount desde los items" do
    params = {
      amount: 999, date: "2026-09-29", description: "Compra semanal", category_id: @categoria.id,
      expense_items_attributes: [
        { name: "Leche", quantity: 2, unit_price: 100 },
        { name: "Pan", quantity: 1, unit_price: 50 }
      ]
    }

    assert_difference "Expense.count", 1 do
      assert_difference "ExpenseItem.count", 2 do
        post "/api/v1/expenses", params: params, headers: @headers, as: :json
      end
    end

    assert_response :created
    assert_equal 250, BigDecimal(response.parsed_body["amount"])
    assert_equal 2, response.parsed_body["expense_items"].size
  end

  test "create sin items respeta el amount enviado" do
    post "/api/v1/expenses", params: { amount: 500, date: "2026-09-28", category_id: @categoria.id },
                             headers: @headers, as: :json

    assert_response :created
    assert_equal 500, BigDecimal(response.parsed_body["amount"])
  end

  test "create ignora user_id y family_group_id enviados y usa el usuario logueado" do
    post "/api/v1/expenses",
         params: { amount: 10, date: "2026-09-29", category_id: @categoria.id,
                   user_id: @otro_user.id, family_group_id: @otra_familia.id },
         headers: @headers, as: :json

    assert_response :created
    gasto = Expense.find(response.parsed_body["id"])
    assert_equal @user.id, gasto.user_id
    assert_equal @familia.id, gasto.family_group_id
  end

  test "create con datos invalidos da 422 y no guarda nada" do
    assert_no_difference "Expense.count" do
      post "/api/v1/expenses", params: { amount: 0, category_id: @categoria.id }, headers: @headers, as: :json
    end

    assert_response :unprocessable_entity
    assert response.parsed_body["errors"].any?
  end

  test "create con vendor_id inexistente da 422" do
    assert_no_difference "Expense.count" do
      post "/api/v1/expenses",
           params: { amount: 10, date: "2026-09-29", category_id: @categoria.id, vendor_id: 999_999 },
           headers: @headers, as: :json
    end

    assert_response :unprocessable_entity
  end
end
