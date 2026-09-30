class PanelController < ApplicationController
  layout false

  def show
    # --- Datos de ejemplo (dummy), solo para ver el diseño ---
    # TODO: reemplazar cada uno de estos por una consulta real cuando
    # conectemos la lógica (usuario logueado, gastos/ingresos del mes, etc.)
    @nombre_usuario = "Norali"
    @grupo_familiar = "Familia Gorosito"

    @ingreso_mes = 450_000   # activo
    @gasto_mes = 310_000     # pasivo
    @porcentaje_gastado = ((@gasto_mes.to_f / @ingreso_mes) * 100).round
    @ahorro_mes = @ingreso_mes - @gasto_mes

    @alerta_gasto_hormiga = { comercio: "Kiosco Don José", monto: 12_400 }
    @tip = "Antes de comprar, preguntate: ¿lo necesito o lo quiero?"
  end
end
