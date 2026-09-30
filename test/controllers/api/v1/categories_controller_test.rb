require "test_helper"

class Api::V1::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    familia = FamilyGroup.create!(name: "Familia de prueba")
    @user = User.create!(user: "tester", password: "password123", family_group: familia)
    @headers = { "Authorization" => "Bearer #{@user.auth_token}" }
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

  test "sin token no entra como un usuario que tiene auth_token nulo" do
    @user.update_column(:auth_token, nil)

    get "/api/v1/categories"

    assert_response :unauthorized
  end

  test "con token valido devuelve las categorias ordenadas por nombre" do
    Category.create!(name: "Transporte")
    Category.create!(name: "Comida")

    get "/api/v1/categories", headers: @headers

    assert_response :ok
    assert_equal %w[Comida Transporte], response.parsed_body.map { |c| c["name"] }
  end
end
