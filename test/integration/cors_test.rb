require "test_helper"

class CorsTest < ActionDispatch::IntegrationTest
  # Se calcula igual que en el initializer: los tests no dependen de que
  # FRONTEND_URL esté definida en la terminal de quien los corre.
  ALLOWED_ORIGIN = CorsConfig.allowed_origins(ENV["FRONTEND_URL"]).first
  OTHER_ORIGIN = "http://evil.example.com".freeze

  test "un preflight desde un origen permitido es aceptado" do
    options "/api/v1/login", headers: preflight_headers(ALLOWED_ORIGIN)

    assert_equal ALLOWED_ORIGIN, response.headers["Access-Control-Allow-Origin"]
    assert_includes response.headers["Access-Control-Allow-Methods"], "POST"
  end

  test "un preflight desde otro origen no es aceptado" do
    options "/api/v1/login", headers: preflight_headers(OTHER_ORIGIN)

    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "un pedido común desde un origen permitido lleva el encabezado CORS" do
    # Sin token la respuesta es 401, pero igual lleva el encabezado CORS: eso es lo que se prueba.
    get "/api/v1/dashboard", headers: { "Origin" => ALLOWED_ORIGIN }

    assert_equal ALLOWED_ORIGIN, response.headers["Access-Control-Allow-Origin"]
  end

  test "las rutas fuera de /api no reciben encabezados CORS" do
    get "/admin/login", headers: { "Origin" => ALLOWED_ORIGIN }

    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "un preflight fuera de /api no recibe encabezados CORS" do
    %w[/admin/login /panel].each do |path|
      options path, headers: preflight_headers(ALLOWED_ORIGIN)

      assert_nil response.headers["Access-Control-Allow-Origin"], "#{path} no debería tener CORS"
    end
  end

  test "parse_origins acepta varios orígenes e ignora espacios y entradas vacías" do
    assert_equal [ "http://a.com", "http://b.com" ], CorsConfig.parse_origins(" http://a.com , ,http://b.com, ")
  end

  test "parse_origins saca la barra final" do
    assert_equal [ "https://app.com" ], CorsConfig.parse_origins("https://app.com/")
  end

  test "parse_origins devuelve una lista vacía si falta el valor" do
    assert_equal [], CorsConfig.parse_origins(nil)
    assert_equal [], CorsConfig.parse_origins("  ")
  end

  test "allowed_origins usa la URL de Vite si el valor está vacío y no es obligatorio" do
    assert_equal [ CorsConfig::DEFAULT_ORIGIN ], CorsConfig.allowed_origins(nil)
  end

  test "allowed_origins falla si el valor está vacío y es obligatorio" do
    assert_raises(RuntimeError) { CorsConfig.allowed_origins("", required: true) }
  end

  test "la variable es obligatoria en producción" do
    assert CorsConfig.required?("production", nil)
  end

  test "la variable no se exige al construir la imagen Docker" do
    assert_not CorsConfig.required?("production", "1")
  end

  test "la variable no se exige en desarrollo ni en test" do
    assert_not CorsConfig.required?("development", nil)
    assert_not CorsConfig.required?("test", nil)
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
