require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  setup do
    @alimentos = Category.create!(name: "Alimentos")
    @verduras = Category.create!(name: "Verduras", parent: @alimentos)
    @hojas = Category.create!(name: "Hojas verdes", parent: @verduras)
    @transporte = Category.create!(name: "Transporte")
  end

  test "una categoria no puede ser su propio padre" do
    @alimentos.parent_id = @alimentos.id

    assert_not @alimentos.valid?
    assert_includes @alimentos.errors[:parent_id], "no puede ser la propia categoría ni una de sus subcategorías"
  end

  test "no puede tener como padre a una de sus subcategorias directas" do
    @alimentos.parent_id = @verduras.id

    assert_not @alimentos.valid?
    assert @alimentos.errors[:parent_id].any?
  end

  test "no puede tener como padre a una subcategoria de un nivel mas profundo" do
    @alimentos.parent_id = @hojas.id

    assert_not @alimentos.valid?
  end

  test "puede tener como padre a una categoria que no es descendiente" do
    @verduras.parent_id = @transporte.id

    assert @verduras.valid?
  end

  test "una categoria nueva con padre existente es valida" do
    assert Category.new(name: "Frutas", parent: @alimentos).valid?
  end

  test "descendant_ids incluye las subcategorias de todos los niveles" do
    assert_equal [ @verduras.id, @hojas.id ].sort, @alimentos.descendant_ids.sort
    assert_equal [ @hojas.id ], @verduras.descendant_ids
    assert_empty @hojas.descendant_ids
  end

  test "descendant_ids de una categoria nueva es vacio" do
    assert_empty Category.new(name: "Nueva").descendant_ids
  end
end
