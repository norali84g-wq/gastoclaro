require "test_helper"

class Api::V1::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    familia = FamilyGroup.create!(name: "Familia de prueba")
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
end
