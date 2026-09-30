require "test_helper"

class Admin::CategoriesControllerTest < ActionDispatch::IntegrationTest
  DESTINOS_PELIGROSOS = [
    "https://evil.example/robo",
    "//evil.example/robo",
    "/\\evil.example/robo",
    "javascript:alert(1)",
    "/ruta\ncon-salto"
  ].freeze

  setup do
    familia = FamilyGroup.create!(name: "Familia de prueba")
    User.create!(user: "admin", password: "password123", admin: true, family_group: familia)
    @categoria = Category.create!(name: "Comida")

    post "/admin/login", params: { user: "admin", password: "password123" }
  end

  test "update vuelve a una ruta interna indicada en return_to" do
    patch "/admin/categories/#{@categoria.id}",
          params: { category: { name: "Comida 2" }, return_to: "/admin/estadisticas" }

    assert_redirected_to "/admin/estadisticas"
  end

  test "update ignora un return_to peligroso y vuelve al listado" do
    DESTINOS_PELIGROSOS.each do |destino|
      patch "/admin/categories/#{@categoria.id}",
            params: { category: { name: "Comida" }, return_to: destino }

      assert_redirected_to admin_categories_path, "return_to #{destino.inspect} deberia ignorarse"
    end
  end

  test "update ignora un return_to que no es un texto" do
    patch "/admin/categories/#{@categoria.id}",
          params: { category: { name: "Comida" }, return_to: [ "/admin/estadisticas" ] }

    assert_redirected_to admin_categories_path
  end

  test "destroy ignora un return_to peligroso" do
    DESTINOS_PELIGROSOS.each do |destino|
      categoria = Category.create!(name: "Temporal")

      delete "/admin/categories/#{categoria.id}", params: { return_to: destino }

      assert_redirected_to admin_categories_path, "return_to #{destino.inspect} deberia ignorarse"
    end
  end

  test "el boton Cancelar usa un return_to interno" do
    get "/admin/categories/#{@categoria.id}/edit", params: { return_to: "/admin/estadisticas" }

    assert_response :ok
    assert_select "a.btn.secondary[href=?]", "/admin/estadisticas", text: "Cancelar"
  end

  test "el boton Cancelar no usa un return_to peligroso" do
    DESTINOS_PELIGROSOS.each do |destino|
      get "/admin/categories/#{@categoria.id}/edit", params: { return_to: destino }

      assert_response :ok
      assert_select "a.btn.secondary[href=?]", admin_categories_path, text: "Cancelar"
      assert_select "a[href*=?]", "javascript:", count: 0
      assert_select "a[href*=?]", "evil.example", count: 0
    end
  end
end
