# Allows the React front-end to call the API from the browser.
#
# FRONTEND_URL accepts one or more origins separated by commas,
# for example: "http://localhost:5173,http://localhost:5174".
# If it is not set, the default Vite development URL is used.
allowed_origins = ENV.fetch("FRONTEND_URL", "http://localhost:5173")
                     .split(",")
                     .map(&:strip)
                     .reject(&:empty?)

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "/api/*",
             headers: :any,
             methods: %i[get post patch put delete options head],
             max_age: 600
  end
end
