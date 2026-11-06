require "test_helper"

# Verifica que la documentación OpenAPI (swagger/v1/openapi.yaml) siga de acuerdo
# con las rutas reales de la API y que Swagger UI se sirva correctamente.
class OpenapiSpecTest < ActionDispatch::IntegrationTest
  SPEC_PATH = Rails.root.join("swagger/v1/openapi.yaml")
  API_PREFIX = "/api/v1".freeze
  HTTP_METHODS = %w[get post put patch delete].freeze
  REQUIRED_KEYS = %w[openapi info paths components].freeze

  # Rutas que existen en Rails pero se dejan fuera de la documentación a propósito.
  # Cada entrada es [método, ruta], por ejemplo ["GET", "/api/v1/ejemplo"].
  UNDOCUMENTED_ROUTES = [].freeze

  setup do
    @spec = YAML.safe_load_file(SPEC_PATH)
  end

  test "the spec file is valid YAML with the required top-level keys" do
    REQUIRED_KEYS.each do |key|
      assert @spec.key?(key), "Falta la clave '#{key}' en #{SPEC_PATH}"
    end
    assert_match(/\A3\.0\./, @spec["openapi"])
  end

  test "every operation has a response, a tag and an operationId" do
    operations = documented_routes.map { |_, _, operation| operation }

    operations.each do |operation|
      assert operation["responses"].present?, "Una operación no tiene respuestas: #{operation['operationId']}"
      assert operation["tags"].present?, "Una operación no tiene tag: #{operation['operationId']}"
    end
    ids = operations.map { |operation| operation["operationId"] }
    assert_equal ids.uniq.size, ids.size, "Hay operationId repetidos"
    assert ids.none?(&:blank?), "Hay operaciones sin operationId"
  end

  test "every $ref points to an existing component" do
    refs = collect_refs(@spec)

    missing = refs.reject { |ref| resolve_ref(ref) }
    assert_empty missing, "Referencias que no existen: #{missing.uniq.join(', ')}"
  end

  test "every API route is documented in the spec" do
    undocumented = rails_routes - documented_pairs - UNDOCUMENTED_ROUTES

    assert_empty undocumented, failure_message(
      "Rutas de la API que no están en swagger/v1/openapi.yaml", undocumented
    )
  end

  test "every documented endpoint exists in the API routes" do
    nonexistent = documented_pairs - rails_routes

    assert_empty nonexistent, failure_message(
      "Endpoints documentados en swagger/v1/openapi.yaml que no existen en las rutas", nonexistent
    )
  end

  test "the OpenAPI file is served at /api-docs/v1/openapi.yaml" do
    get "/api-docs/v1/openapi.yaml"

    assert_response :success
    assert_equal @spec["info"]["title"], YAML.safe_load(response.body)["info"]["title"]
  end

  test "Swagger UI is served at /api-docs" do
    get "/api-docs/index.html"

    assert_response :success
    assert_includes response.body, "swagger-ui"
  end

  test "Swagger UI does not load anything from the internet" do
    get "/api-docs/index.html"

    assert_response :success
    assert_no_match(/(?:href|src)=["']https?:\/\//, response.body)
    assert_includes response.body, '"validatorUrl":null'
  end

  private

  # Lista de [método, ruta completa, operación] tomada del YAML.
  def documented_routes
    @spec["paths"].flat_map do |path, item|
      item.slice(*HTTP_METHODS).map do |verb, operation|
        [ verb.upcase, "#{API_PREFIX}#{path}", operation ]
      end
    end
  end

  def documented_pairs
    documented_routes.map { |verb, path, _| [ verb, path ] }.sort
  end

  # Rutas reales de la API, con el mismo formato que el YAML: ":id" se escribe "{id}"
  # y se descarta el sufijo opcional "(.:format)".
  def rails_routes
    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.sub("(.:format)", "")
      next unless path.start_with?("#{API_PREFIX}/")

      [ route.verb, path.gsub(/:(\w+)/, '{\1}') ]
    end.sort
  end

  def failure_message(title, pairs)
    lines = pairs.map { |verb, path| "  #{verb} #{path}" }
    "#{title}:\n#{lines.join("\n")}"
  end

  def collect_refs(node)
    case node
    when Hash then node.flat_map { |key, value| key == "$ref" ? [ value ] : collect_refs(value) }
    when Array then node.flat_map { |value| collect_refs(value) }
    else []
    end
  end

  def resolve_ref(ref)
    return false unless ref.start_with?("#/")

    ref.delete_prefix("#/").split("/").reduce(@spec) do |node, key|
      node.is_a?(Hash) ? node[key] : nil
    end
  end
end
