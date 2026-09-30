require "test_helper"

class SavingsGoalTest < ActiveSupport::TestCase
  test "progress devuelve el porcentaje ahorrado redondeado" do
    assert_equal 25, SavingsGoal.new(target_amount: 1000, saved_amount: 250).progress
    assert_equal 33, SavingsGoal.new(target_amount: 300, saved_amount: 100).progress
  end

  test "progress devuelve 0 si el objetivo es 0" do
    assert_equal 0, SavingsGoal.new(target_amount: 0, saved_amount: 0).progress
  end

  test "falta_ahorrar es objetivo menos ahorrado y nunca negativo" do
    assert_equal 700, SavingsGoal.new(target_amount: 1000, saved_amount: 300).falta_ahorrar
    assert_equal 0, SavingsGoal.new(target_amount: 1000, saved_amount: 1500).falta_ahorrar
  end

  test "meses_restantes cuenta los meses hasta la fecha limite" do
    travel_to Date.new(2026, 9, 15) do
      assert_equal 4, SavingsGoal.new(deadline: Date.new(2027, 1, 10)).meses_restantes
    end
  end

  test "meses_restantes es 1 sin fecha limite, en el mismo mes o con fecha pasada" do
    travel_to Date.new(2026, 9, 15) do
      assert_equal 1, SavingsGoal.new(deadline: nil).meses_restantes
      assert_equal 1, SavingsGoal.new(deadline: Date.new(2026, 9, 30)).meses_restantes
      assert_equal 1, SavingsGoal.new(deadline: Date.new(2026, 1, 1)).meses_restantes
    end
  end

  test "monto_mensual_necesario reparte lo que falta entre los meses restantes" do
    travel_to Date.new(2026, 9, 15) do
      meta = SavingsGoal.new(target_amount: 1000, saved_amount: 300, deadline: Date.new(2027, 4, 1))
      assert_equal 100, meta.monto_mensual_necesario

      meta = SavingsGoal.new(target_amount: 1000, saved_amount: 0, deadline: Date.new(2026, 12, 1))
      assert_equal BigDecimal("333.33"), meta.monto_mensual_necesario
    end
  end

  test "cumplida? es verdadera cuando lo ahorrado alcanza el objetivo" do
    assert SavingsGoal.new(target_amount: 1000, saved_amount: 1000).cumplida?
    assert_not SavingsGoal.new(target_amount: 1000, saved_amount: 999).cumplida?
  end

  test "el nombre es obligatorio y el objetivo debe ser mayor a 0" do
    familia = FamilyGroup.create!(name: "Familia de prueba")

    assert_not SavingsGoal.new(family_group: familia, name: "", target_amount: 100).valid?
    assert_not SavingsGoal.new(family_group: familia, name: "Viaje", target_amount: 0).valid?
    assert SavingsGoal.new(family_group: familia, name: "Viaje", target_amount: 100).valid?
  end
end
