require "test_helper"

class InstallmentPurchaseTest < ActiveSupport::TestCase
  def compra(attrs = {})
    InstallmentPurchase.new({ total_amount: 1200, installments_count: 12, first_period: "2026-09" }.merge(attrs))
  end

  test "monto_por_cuota divide el total y redondea a 2 decimales" do
    assert_equal 100, compra.monto_por_cuota
    assert_equal BigDecimal("333.33"), compra(total_amount: 1000, installments_count: 3).monto_por_cuota
  end

  test "periodos lista un periodo por cuota, cruzando de anio" do
    assert_equal %w[2026-11 2026-12 2027-01], compra(first_period: "2026-11", installments_count: 3).periodos
  end

  test "cuotas_pagadas cuenta las cuotas hasta un periodo dado" do
    c = compra(first_period: "2026-09", installments_count: 6)

    assert_equal 0, c.cuotas_pagadas("2026-08")
    assert_equal 1, c.cuotas_pagadas("2026-09")
    assert_equal 3, c.cuotas_pagadas("2026-11")
    assert_equal 6, c.cuotas_pagadas("2030-01")
  end

  test "cuotas_restantes es el total menos las pagadas y nunca negativo" do
    c = compra(first_period: "2026-09", installments_count: 6)

    assert_equal 3, c.cuotas_restantes("2026-11")
    assert_equal 0, c.cuotas_restantes("2030-01")
  end

  test "finalizada? es verdadera solo cuando no quedan cuotas" do
    c = compra(first_period: "2026-09", installments_count: 6)

    assert_not c.finalizada?("2027-01")
    assert c.finalizada?("2027-02")
  end

  test "sin argumento usa el mes actual" do
    c = compra(first_period: "2026-09", installments_count: 6)

    travel_to Date.new(2026, 11, 20) do
      assert_equal 3, c.cuotas_pagadas
      assert_equal 3, c.cuotas_restantes
      assert_not c.finalizada?
    end
  end

  test "validaciones de cantidad de cuotas, formato de periodo y monto" do
    familia = FamilyGroup.create!(name: "Familia de prueba")
    categoria = Category.create!(name: "Electro")
    base = { family_group: familia, category: categoria, description: "Heladera" }

    assert compra(base).valid?
    assert_not compra(base.merge(installments_count: 0)).valid?
    assert_not compra(base.merge(installments_count: 49)).valid?
    assert_not compra(base.merge(first_period: "09/2026")).valid?
    assert_not compra(base.merge(total_amount: 0)).valid?
    assert_not compra(base.merge(description: "")).valid?
  end
end
