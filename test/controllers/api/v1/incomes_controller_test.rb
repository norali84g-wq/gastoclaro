require "test_helper"

class Api::V1::IncomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @familia = FamilyGroup.create!(name: "Familia de prueba")
    @user = User.create!(user: "tester", password: "password123", family_group: @familia)
    @headers = { "Authorization" => "Bearer #{@user.auth_token}" }

    @otra_familia = FamilyGroup.create!(name: "Otra familia")
    @otro_user = User.create!(user: "otro", password: "password123", family_group: @otra_familia)
  end

  test "create sin token da 401 y no guarda nada" do
    assert_no_difference "Income.count" do
      post "/api/v1/incomes", params: { amount: 1000, date: "2026-09-15" }, as: :json
    end

    assert_response :unauthorized
  end

  test "create con datos validos da 201 y el ingreso queda a nombre del usuario logueado" do
    assert_difference "Income.count", 1 do
      post "/api/v1/incomes", params: { amount: 1500.5, date: "2026-09-15" }, headers: @headers, as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal BigDecimal("1500.5"), BigDecimal(body["amount"])
    assert_equal "2026-09-15", body["date"]
    assert_equal @user.id, Income.find(body["id"]).user_id
  end

  test "create ignora un user_id enviado y usa el usuario logueado" do
    post "/api/v1/incomes", params: { amount: 100, date: "2026-09-15", user_id: @otro_user.id },
                            headers: @headers, as: :json

    assert_response :created
    assert_equal @user.id, Income.find(response.parsed_body["id"]).user_id
    assert_equal 0, @otro_user.incomes.count
  end

  test "create con monto 0, negativo o vacio da 422 y no guarda" do
    [ 0, -50, nil ].each do |monto|
      assert_no_difference "Income.count" do
        post "/api/v1/incomes", params: { amount: monto, date: "2026-09-15" }, headers: @headers, as: :json
      end

      assert_response :unprocessable_entity, "amount #{monto.inspect} deberia rechazarse"
      assert response.parsed_body["errors"].any?
    end
  end

  test "create sin fecha da 422 y no guarda" do
    assert_no_difference "Income.count" do
      post "/api/v1/incomes", params: { amount: 100 }, headers: @headers, as: :json
    end

    assert_response :unprocessable_entity
  end
end
