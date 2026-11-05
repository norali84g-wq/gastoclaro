# Swagger UI en /api-docs. Lee la especificación que publica rswag-api.
Rswag::Ui.configure do |config|
  config.openapi_endpoint "/api-docs/v1/openapi.yaml", "API de GastoClaro v1"
end
