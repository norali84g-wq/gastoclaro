require "test_helper"

class Admin::CategoriesParentCyclesTest < ActionDispatch::IntegrationTest
  setup do
    familia = FamilyGroup.create!(name: "Familia de prueba")
    User.create!(user: "admin", password: "password123", admin: true, family_group: familia)
    @alimentos = Category.create!(name: "Alimentos")
    @verduras = Category.create!(name: "Verduras", parent: @alimentos)

    post "/admin/login", params: { user: "admin", password: "password123" }
  end

  test "update rechaza elegir una subcategoria propia como padre y no guarda el cambio" do
    patch "/admin/categories/#{@alimentos.id}", params: { category: { parent_id: @verduras.id } }

    assert_response :unprocessable_entity
    assert_nil @alimentos.reload.parent_id
  end

  test "el formulario de edicion no ofrece a la propia categoria ni a sus subcategorias como padre" do
    get "/admin/categories/#{@alimentos.id}/edit"

    assert_response :ok
    assert_select "select#category_parent_id option[value=?]", @alimentos.id.to_s, count: 0
    assert_select "select#category_parent_id option[value=?]", @verduras.id.to_s, count: 0
  end

  test "el formulario de edicion si ofrece una categoria que no es descendiente" do
    otra = Category.create!(name: "Transporte")

    get "/admin/categories/#{@alimentos.id}/edit"

    assert_select "select#category_parent_id option[value=?]", otra.id.to_s, count: 1
  end

  test "el formulario de una categoria nueva ofrece todas las categorias" do
    get "/admin/categories/new"

    assert_response :ok
    assert_select "select#category_parent_id option[value=?]", @alimentos.id.to_s, count: 1
    assert_select "select#category_parent_id option[value=?]", @verduras.id.to_s, count: 1
  end
end
