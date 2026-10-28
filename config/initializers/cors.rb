# Permite que el front en React llame a la API desde el navegador.
#
# FRONTEND_URL acepta uno o más orígenes separados por comas, por ejemplo
# "http://localhost:5173,http://localhost:5174". Una barra final se ignora.
# En desarrollo y test, si no está definida, se usa la URL de Vite.
# En producción es obligatoria: sin ella el navegador bloquea todos los pedidos.
module CorsConfig
  DEFAULT_ORIGIN = "http://localhost:5173".freeze

  # Convierte el texto de FRONTEND_URL en una lista de orígenes limpios.
  def self.parse_origins(value)
    value.to_s.split(",").map { |origin| origin.strip.sub(%r{/+\z}, "") }.reject(&:empty?)
  end

  # La variable es obligatoria en producción, salvo al construir la imagen Docker:
  # ahí Rails carga la app con SECRET_KEY_BASE_DUMMY y sin las variables reales.
  def self.required?(rails_env, dummy_key)
    rails_env.to_s == "production" && dummy_key.to_s.empty?
  end

  def self.allowed_origins(value, required: false)
    origins = parse_origins(value)
    return origins if origins.any?

    raise "Falta definir la variable de entorno FRONTEND_URL" if required

    [ DEFAULT_ORIGIN ]
  end
end

allowed_origins = CorsConfig.allowed_origins(
  ENV["FRONTEND_URL"],
  required: CorsConfig.required?(Rails.env, ENV["SECRET_KEY_BASE_DUMMY"])
)

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "/api/*",
             headers: :any,
             methods: %i[get post patch put delete options head],
             max_age: 600
  end
end
