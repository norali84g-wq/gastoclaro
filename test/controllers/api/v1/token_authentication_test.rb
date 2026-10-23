require "test_helper"

class Api::V1::TokenAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    familia = FamilyGroup.create!(name: "Familia de prueba")
    @user = User.create!(user: "tester", password: "password123", family_group: familia)
    @token = AuthToken.encode(@user)
    @headers = { "Authorization" => "Bearer #{@token}" }
  end

  test "un token valido permite entrar" do
    get "/api/v1/categories", headers: @headers

    assert_response :ok
  end

  test "un token vencido da 401" do
    travel_to((AuthToken::EXPIRATION + 1.minute).from_now) do
      get "/api/v1/categories", headers: @headers
    end

    assert_response :unauthorized
  end

  test "un token alterado da 401" do
    get "/api/v1/categories", headers: { "Authorization" => "Bearer #{@token}x" }

    assert_response :unauthorized
  end

  test "un token firmado con otra clave da 401" do
    falso = JWT.encode({ sub: @user.id.to_s, ver: 0, exp: 1.hour.from_now.to_i }, "otra-clave", AuthToken::ALGORITHM)

    get "/api/v1/categories", headers: { "Authorization" => "Bearer #{falso}" }

    assert_response :unauthorized
  end

  test "logout devuelve 204 e invalida el token" do
    delete "/api/v1/logout", headers: @headers

    assert_response :no_content

    get "/api/v1/categories", headers: @headers

    assert_response :unauthorized
  end

  test "logout sin token da 401" do
    delete "/api/v1/logout"

    assert_response :unauthorized
  end

  test "despues de un logout se puede volver a iniciar sesion" do
    delete "/api/v1/logout", headers: @headers

    post "/api/v1/login", params: { user: "tester", password: "password123" }, as: :json

    assert_response :ok
    get "/api/v1/categories", headers: { "Authorization" => "Bearer #{response.parsed_body["token"]}" }

    assert_response :ok
  end
end
