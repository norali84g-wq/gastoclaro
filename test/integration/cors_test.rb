require "test_helper"

class CorsTest < ActionDispatch::IntegrationTest
  # Se calcula igual que en el initializer: los tests no dependen de que
  # FRONTEND_URL esté definida en la terminal de quien los corre.
  ALLOWED_ORIGIN = CorsConfig.allowed_origins(ENV["FRONTEND_URL"]).first
  OTHER_ORIGIN = "http://evil.example.com".freeze

  test "preflight from an allowed origin is accepted" do
    options "/api/v1/login", headers: preflight_headers(ALLOWED_ORIGIN)

    assert_equal ALLOWED_ORIGIN, response.headers["Access-Control-Allow-Origin"]
    assert_includes response.headers["Access-Control-Allow-Methods"], "POST"
  end

  test "preflight from another origin is not accepted" do
    options "/api/v1/login", headers: preflight_headers(OTHER_ORIGIN)

    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "a regular request from an allowed origin gets the CORS header" do
    # Sin token la respuesta es 401, pero igual lleva el encabezado CORS: eso es lo que se prueba.
    get "/api/v1/dashboard", headers: { "Origin" => ALLOWED_ORIGIN }

    assert_equal ALLOWED_ORIGIN, response.headers["Access-Control-Allow-Origin"]
  end

  test "routes outside /api do not get CORS headers" do
    get "/admin/login", headers: { "Origin" => ALLOWED_ORIGIN }

    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "parse_origins accepts several origins and ignores spaces and empty entries" do
    assert_equal [ "http://a.com", "http://b.com" ], CorsConfig.parse_origins(" http://a.com , ,http://b.com, ")
  end

  test "parse_origins removes the trailing slash" do
    assert_equal [ "https://app.com" ], CorsConfig.parse_origins("https://app.com/")
  end

  test "parse_origins returns an empty list when the value is missing" do
    assert_equal [], CorsConfig.parse_origins(nil)
    assert_equal [], CorsConfig.parse_origins("  ")
  end

  test "allowed_origins uses the Vite URL when the value is blank and not required" do
    assert_equal [ CorsConfig::DEFAULT_ORIGIN ], CorsConfig.allowed_origins(nil)
  end

  test "allowed_origins raises when the value is blank and required" do
    assert_raises(RuntimeError) { CorsConfig.allowed_origins("", required: true) }
  end

  private

  def preflight_headers(origin)
    {
      "Origin" => origin,
      "Access-Control-Request-Method" => "POST",
      "Access-Control-Request-Headers" => "authorization,content-type"
    }
  end
end
