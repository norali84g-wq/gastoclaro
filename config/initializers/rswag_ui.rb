# Swagger UI en /api-docs. Lee la especificación que publica rswag-api.
Rswag::Ui.configure do |config|
  config.openapi_endpoint "/api-docs/v1/openapi.yaml", "API de GastoClaro v1"

  # Sin esto, desde otra IP distinta de localhost Swagger UI consulta validator.swagger.io.
  config.config_object[:validatorUrl] = nil
end
