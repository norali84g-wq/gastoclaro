require "test_helper"

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    familia = FamilyGroup.create!(name: "Familia de prueba")
    User.create!(user: "admin", password: "password123", admin: true, email: "admin@example.com", family_group: familia)
    User.create!(user: "comun", password: "password123", family_group: familia)
  end

  test "el login de administracion acepta el usuario tal cual" do
    post "/admin/login", params: { user: "admin", password: "password123" }

    assert_redirected_to admin_root_path
  end

  test "el login de administracion acepta el usuario en mayusculas" do
    post "/admin/login", params: { user: "ADMIN", password: "password123" }

    assert_redirected_to admin_root_path
  end

  test "el login de administracion acepta el usuario con la primera letra en mayuscula" do
    post "/admin/login", params: { user: "Admin", password: "password123" }

    assert_redirected_to admin_root_path
  end

  test "el login de administracion acepta espacios alrededor del usuario" do
    post "/admin/login", params: { user: " admin ", password: "password123" }

    assert_redirected_to admin_root_path
  end

  test "password_remains_case_sensitive en el login de administracion" do
    post "/admin/login", params: { user: "admin", password: "PASSWORD123" }

    assert_response :unprocessable_entity
  end

  test "un usuario que no es administrador no entra por el login de administracion" do
    post "/admin/login", params: { user: "Comun", password: "password123" }

    assert_response :unprocessable_entity
  end

  test "el login de administracion con un usuario inexistente da el mismo error" do
    post "/admin/login", params: { user: "nadie", password: "password123" }

    assert_response :unprocessable_entity
  end
end
