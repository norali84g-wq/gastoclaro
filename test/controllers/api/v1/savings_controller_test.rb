require "test_helper"

class Api::V1::SavingsControllerTest < ActionDispatch::IntegrationTest
  HOY = Date.new(2026, 9, 15)

  setup do
    @familia = FamilyGroup.create!(name: "Familia de prueba", savings_percentage: 15)
    @user = User.create!(user: "tester", password: "password123", family_group: @familia)
    @headers = { "Authorization" => "Bearer #{AuthToken.encode(@user)}" }
    @otra_familia = FamilyGroup.create!(name: "Otra familia")
    @otro_user = User.create!(user: "otro", password: "password123", family_group: @otra_familia)
    @comida = Category.create!(name: "Comida")

    travel_to HOY
  end

  def savings
    get "/api/v1/savings", headers: @headers
    response.parsed_body
  end

  def decimal(valor)
    BigDecimal(valor.to_s)
  end

  test "sin token da 401" do
    get "/api/v1/savings"

    assert_response :unauthorized
  end

  test "sin movimientos devuelve la meta y ningun mes" do
    body = savings

    assert_response :ok
    assert_equal 15, body["savings_goal_percentage"]
    assert_equal [], body["months"]
  end

  test "lista cada mes desde el primer movimiento hasta el mes en curso, con el acumulado" do
    Income.create!(user: @user, amount: 1000, date: Date.new(2026, 6, 10))
    Expense.create!(user: @user, category: @comida, amount: 300, date: Date.new(2026, 6, 12))
    Income.create!(user: @user, amount: 500, date: Date.new(2026, 9, 1))
    Expense.create!(user: @user, category: @comida, amount: 700, date: Date.new(2026, 9, 5))

    meses = savings["months"]

    assert_equal %w[2026-06 2026-07 2026-08 2026-09], meses.map { |m| m["month"] }
    junio, julio, _agosto, septiembre = meses
    assert_equal 700, decimal(junio["savings"])
    assert_equal 700, decimal(junio["accumulated"])
    # Un mes sin movimientos aparece en cero y arrastra el acumulado.
    assert_equal 0, decimal(julio["income"])
    assert_equal 700, decimal(julio["accumulated"])
    assert_equal(-200, decimal(septiembre["savings"]))
    assert_equal 500, decimal(septiembre["accumulated"])
  end

  test "solo cuenta los movimientos del usuario" do
    Income.create!(user: @user, amount: 100, date: Date.new(2026, 9, 1))
    Income.create!(user: @otro_user, amount: 9999, date: Date.new(2026, 8, 1))

    meses = savings["months"]

    assert_equal [ "2026-09" ], meses.map { |m| m["month"] }
    assert_equal 100, decimal(meses.first["income"])
  end

  test "no cuenta los movimientos de meses futuros" do
    Income.create!(user: @user, amount: 100, date: Date.new(2026, 9, 1))
    Income.create!(user: @user, amount: 500, date: Date.new(2026, 12, 1))

    assert_equal [ "2026-09" ], savings["months"].map { |m| m["month"] }
  end
end
