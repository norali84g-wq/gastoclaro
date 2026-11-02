require "test_helper"

class Api::V1::IncomesIndexUpdateDestroyTest < ActionDispatch::IntegrationTest
  setup do
    @familia = FamilyGroup.create!(name: "Familia de prueba")
    @user = User.create!(user: "tester", password: "password123", family_group: @familia)
    @admin = User.create!(user: "jefa", password: "password123", family_group: @familia, admin: true)
    @ingreso = Income.create!(user: @user, amount: 1000, date: "2026-09-01")

    @otra_familia = FamilyGroup.create!(name: "Otra familia")
    @otro_user = User.create!(user: "otro", password: "password123", family_group: @otra_familia)
    @ingreso_ajeno = Income.create!(user: @otro_user, amount: 777, date: "2026-09-02")
  end

  def headers_for(user)
    { "Authorization" => "Bearer #{AuthToken.encode(user)}" }
  end

  # --- GET /incomes ---

  test "index sin token da 401" do
    get "/api/v1/incomes"

    assert_response :unauthorized
  end

  test "index devuelve solo los ingresos del usuario, con su usuario" do
    get "/api/v1/incomes", headers: headers_for(@user)

    assert_response :ok
    ingresos = response.parsed_body
    assert_equal [ @ingreso.id ], ingresos.map { |i| i["id"] }
    assert_equal({ "id" => @user.id, "user" => "tester" }, ingresos.first["user"])
    assert_equal "2026-09-01", ingresos.first["date"]
  end

  test "index ordena del mas reciente al mas antiguo" do
    reciente = Income.create!(user: @user, amount: 50, date: "2026-10-15")

    get "/api/v1/incomes", headers: headers_for(@user)

    assert_equal [ reciente.id, @ingreso.id ], response.parsed_body.map { |i| i["id"] }
  end

  test "el admin ve los ingresos de todos" do
    get "/api/v1/incomes", headers: headers_for(@admin)

    assert_response :ok
    assert_equal [ @ingreso.id, @ingreso_ajeno.id ].sort, response.parsed_body.map { |i| i["id"] }.sort
  end

  # --- POST /incomes ---

  test "create devuelve tambien el usuario" do
    post "/api/v1/incomes", params: { amount: 100, date: "2026-09-15" }, headers: headers_for(@user), as: :json

    assert_response :created
    assert_equal({ "id" => @user.id, "user" => "tester" }, response.parsed_body["user"])
  end

  # --- PATCH /incomes/:id ---

  test "update sin token da 401" do
    patch "/api/v1/incomes/#{@ingreso.id}", params: { amount: 1 }, as: :json

    assert_response :unauthorized
  end

  test "update cambia solo lo que se envia" do
    patch "/api/v1/incomes/#{@ingreso.id}", params: { amount: 1200 }, headers: headers_for(@user), as: :json

    assert_response :ok
    assert_equal 1200, BigDecimal(response.parsed_body["amount"])
    assert_equal "2026-09-01", response.parsed_body["date"]
    assert_equal 1200, @ingreso.reload.amount
  end

  test "update puede cambiar la fecha" do
    patch "/api/v1/incomes/#{@ingreso.id}", params: { date: "2026-09-20" }, headers: headers_for(@user), as: :json

    assert_response :ok
    assert_equal "2026-09-20", response.parsed_body["date"]
  end

  test "update de un ingreso de otro usuario da 404 y no lo modifica" do
    patch "/api/v1/incomes/#{@ingreso_ajeno.id}", params: { amount: 1 }, headers: headers_for(@user), as: :json

    assert_response :not_found
    assert_equal [ { "field" => "base", "message" => "No encontrado" } ], response.parsed_body["errors"]
    assert_equal 777, @ingreso_ajeno.reload.amount
  end

  test "update de un ingreso que no existe da 404" do
    patch "/api/v1/incomes/0", params: { amount: 1 }, headers: headers_for(@user), as: :json

    assert_response :not_found
  end

  test "el admin puede editar el ingreso de otro usuario" do
    patch "/api/v1/incomes/#{@ingreso_ajeno.id}", params: { amount: 900 }, headers: headers_for(@admin), as: :json

    assert_response :ok
    assert_equal 900, @ingreso_ajeno.reload.amount
    assert_equal @otro_user.id, @ingreso_ajeno.user_id
  end

  test "update ignora user_id enviado: el ingreso no cambia de dueno" do
    patch "/api/v1/incomes/#{@ingreso.id}", params: { amount: 5, user_id: @otro_user.id },
                                            headers: headers_for(@user), as: :json

    assert_response :ok
    assert_equal @user.id, @ingreso.reload.user_id
  end

  test "update con monto 0, negativo o vacio da 422 y no modifica" do
    [ 0, -50, nil ].each do |monto|
      patch "/api/v1/incomes/#{@ingreso.id}", params: { amount: monto }, headers: headers_for(@user), as: :json

      assert_response :unprocessable_entity, "amount #{monto.inspect} deberia rechazarse"
      assert_equal "amount", response.parsed_body["errors"].first["field"]
      assert_equal 1000, @ingreso.reload.amount
    end
  end

  # --- DELETE /incomes/:id ---

  test "destroy sin token da 401" do
    assert_no_difference "Income.count" do
      delete "/api/v1/incomes/#{@ingreso.id}"
    end

    assert_response :unauthorized
  end

  test "destroy borra el ingreso y responde 204 sin cuerpo" do
    assert_difference "Income.count", -1 do
      delete "/api/v1/incomes/#{@ingreso.id}", headers: headers_for(@user)
    end

    assert_response :no_content
    assert_empty response.body
  end

  test "destroy de un ingreso de otro usuario da 404 y no lo borra" do
    assert_no_difference "Income.count" do
      delete "/api/v1/incomes/#{@ingreso_ajeno.id}", headers: headers_for(@user)
    end

    assert_response :not_found
  end

  test "el admin puede borrar el ingreso de otro usuario" do
    assert_difference "Income.count", -1 do
      delete "/api/v1/incomes/#{@ingreso_ajeno.id}", headers: headers_for(@admin)
    end

    assert_response :no_content
  end

  test "destroy de un ingreso que no existe da 404" do
    delete "/api/v1/incomes/0", headers: headers_for(@user)

    assert_response :not_found
  end
end
