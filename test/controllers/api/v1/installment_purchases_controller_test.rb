require "test_helper"

class Api::V1::InstallmentPurchasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @familia = FamilyGroup.create!(name: "Familia de prueba")
    @user = User.create!(user: "tester", password: "password123", family_group: @familia)
    @admin = User.create!(user: "jefa", password: "password123", family_group: @familia, admin: true)
    @categoria = Category.create!(name: "Electro")
    @mes_actual = Date.current.strftime("%Y-%m")
    @compra = InstallmentPurchase.create!(
      family_group: @familia, category: @categoria, description: "Heladera",
      total_amount: 1200, installments_count: 12, first_period: @mes_actual
    )

    @otra_familia = FamilyGroup.create!(name: "Otra familia")
    @otro_user = User.create!(user: "otro", password: "password123", family_group: @otra_familia)
    @compra_ajena = InstallmentPurchase.create!(
      family_group: @otra_familia, category: @categoria, description: "Lavarropas",
      total_amount: 600, installments_count: 6, first_period: @mes_actual
    )
  end

  def headers_for(user)
    { "Authorization" => "Bearer #{AuthToken.encode(user)}" }
  end

  def datos_validos(extra = {})
    { description: "Televisor", total_amount: 900, installments_count: 3,
      first_period: @mes_actual, category_id: @categoria.id }.merge(extra)
  end

  test "index sin token da 401" do
    get "/api/v1/installment_purchases"

    assert_response :unauthorized
  end

  test "index devuelve solo las compras del grupo familiar, con los campos calculados" do
    get "/api/v1/installment_purchases", headers: headers_for(@user)

    assert_response :ok
    compras = response.parsed_body
    assert_equal [ "Heladera" ], compras.map { |c| c["description"] }
    assert_equal 100, BigDecimal(compras.first["installment_amount"])
    assert_equal 11, compras.first["remaining_installments"]
  end

  test "el admin ve las compras de todos los grupos" do
    get "/api/v1/installment_purchases", headers: headers_for(@admin)

    assert_equal [ "Heladera", "Lavarropas" ], response.parsed_body.map { |c| c["description"] }.sort
  end

  test "create con datos validos da 201 y queda en el grupo del usuario" do
    assert_difference "InstallmentPurchase.count", 1 do
      post "/api/v1/installment_purchases", params: datos_validos, headers: headers_for(@user), as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 300, BigDecimal(body["installment_amount"])
    assert_equal 2, body["remaining_installments"]
    assert_equal @familia.id, InstallmentPurchase.find(body["id"]).family_group_id
  end

  test "create con vendor existente lo guarda" do
    vendor = Vendor.create!(name: "Tienda")

    post "/api/v1/installment_purchases", params: datos_validos(vendor_id: vendor.id),
                                          headers: headers_for(@user), as: :json

    assert_response :created
    assert_equal vendor.id, response.parsed_body["vendor_id"]
  end

  test "create no genera consumo en el dashboard" do
    assert_no_difference "Expense.count" do
      post "/api/v1/installment_purchases", params: datos_validos, headers: headers_for(@user), as: :json
    end

    assert_response :created
  end

  test "create con datos invalidos da 422 y no guarda" do
    invalidos = [
      [ { description: "" }, "description" ],
      [ { total_amount: 0 }, "total_amount" ],
      [ { installments_count: 0 }, "installments_count" ],
      [ { installments_count: 49 }, "installments_count" ],
      [ { first_period: "2026-9" }, "first_period" ],
      [ { first_period: "2026-13" }, "first_period" ],
      [ { category_id: 0 }, "category_id" ],
      [ { vendor_id: 0 }, "vendor_id" ]
    ]

    invalidos.each do |cambio, campo|
      assert_no_difference "InstallmentPurchase.count" do
        post "/api/v1/installment_purchases", params: datos_validos(cambio),
                                              headers: headers_for(@user), as: :json
      end

      assert_response :unprocessable_entity, "#{cambio.inspect} deberia rechazarse"
      assert_includes response.parsed_body["errors"].map { |e| e["field"] }, campo
    end
  end

  test "create rechaza un vendor_id que no es un valor simple (intento de inyeccion SQL)" do
    Vendor.create!(name: "Tienda")

    post "/api/v1/installment_purchases", params: datos_validos(vendor_id: [ "1=1" ]),
                                          headers: headers_for(@user), as: :json

    assert_response :unprocessable_entity
  end

  test "update cambia solo lo que se envia y recalcula las cuotas" do
    patch "/api/v1/installment_purchases/#{@compra.id}", params: { installments_count: 6 },
                                                         headers: headers_for(@user), as: :json

    assert_response :ok
    assert_equal 200, BigDecimal(response.parsed_body["installment_amount"])
    assert_equal 5, response.parsed_body["remaining_installments"]
    assert_equal "Heladera", response.parsed_body["description"]
  end

  test "update con datos invalidos da 422 y no modifica" do
    patch "/api/v1/installment_purchases/#{@compra.id}", params: { installments_count: 100 },
                                                         headers: headers_for(@user), as: :json

    assert_response :unprocessable_entity
    assert_equal 12, @compra.reload.installments_count
  end

  test "update de una compra de otro grupo da 404 y no la modifica" do
    patch "/api/v1/installment_purchases/#{@compra_ajena.id}", params: { description: "hackeada" },
                                                               headers: headers_for(@user), as: :json

    assert_response :not_found
    assert_equal "Lavarropas", @compra_ajena.reload.description
  end

  test "el admin puede editar la compra de otro grupo" do
    patch "/api/v1/installment_purchases/#{@compra_ajena.id}", params: { description: "Lavarropas nuevo" },
                                                               headers: headers_for(@admin), as: :json

    assert_response :ok
    assert_equal "Lavarropas nuevo", @compra_ajena.reload.description
  end

  test "destroy sin token da 401" do
    assert_no_difference "InstallmentPurchase.count" do
      delete "/api/v1/installment_purchases/#{@compra.id}"
    end

    assert_response :unauthorized
  end

  test "destroy borra la compra y responde 204 sin cuerpo" do
    assert_difference "InstallmentPurchase.count", -1 do
      delete "/api/v1/installment_purchases/#{@compra.id}", headers: headers_for(@user)
    end

    assert_response :no_content
    assert_empty response.body
  end

  test "destroy de una compra de otro grupo da 404 y no la borra" do
    assert_no_difference "InstallmentPurchase.count" do
      delete "/api/v1/installment_purchases/#{@compra_ajena.id}", headers: headers_for(@user)
    end

    assert_response :not_found
  end

  test "destroy de una compra que no existe da 404" do
    delete "/api/v1/installment_purchases/0", headers: headers_for(@user)

    assert_response :not_found
  end
end
