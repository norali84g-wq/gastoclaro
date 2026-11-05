# Sirve los archivos OpenAPI de swagger/ como /api-docs/<carpeta>/<archivo>.
# Ejemplo: swagger/v1/openapi.yaml se publica en /api-docs/v1/openapi.yaml.
Rswag::Api.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s
end
