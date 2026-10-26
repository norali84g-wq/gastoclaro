require "test_helper"

class CorsTest < ActionDispatch::IntegrationTest
  ALLOWED_ORIGIN = "http://localhost:5173".freeze
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
    get "/api/v1/dashboard", headers: { "Origin" => ALLOWED_ORIGIN }

    assert_equal ALLOWED_ORIGIN, response.headers["Access-Control-Allow-Origin"]
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
