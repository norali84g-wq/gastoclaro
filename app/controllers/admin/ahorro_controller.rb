class Admin::AhorroController < Admin::BaseController
  def show
    family_group = current_admin.family_group
    hoy = Date.current

    fecha_ingreso = Income.joins(:user).where(users: { family_group_id: family_group.id }).minimum(:date)
    fecha_gasto = Expense.where(family_group_id: family_group.id).minimum(:date)
    primer_mes = [fecha_ingreso, fecha_gasto].compact.min&.beginning_of_month || hoy.beginning_of_month

    meses = []
    mes_actual = primer_mes
    while mes_actual <= hoy.beginning_of_month
      meses << mes_actual
      mes_actual = mes_actual.next_month
    end

    acumulado = 0
    detalle_mensual = meses.map do |mes_inicio|
      mes_fin = mes_inicio.end_of_month

      ingreso_mes = Income.joins(:user)
                           .where(users: { family_group_id: family_group.id })
                           .where(date: mes_inicio..mes_fin)
                           .sum(:amount)

      consumo_mes = Expense.where(family_group_id: family_group.id)
                            .where(date: mes_inicio..mes_fin)
                            .sum(:amount)

      ahorro_mes = ingreso_mes - consumo_mes
      acumulado += ahorro_mes

      { mes: mes_inicio, ingreso: ingreso_mes, consumo: consumo_mes, ahorro: ahorro_mes, acumulado: acumulado }
    end

    @ahorro_por_anio = detalle_mensual.group_by { |m| m[:mes].year }
    @meta_ahorro_porcentaje = family_group.savings_percentage
    @savings_goals = family_group.savings_goals.order(:deadline)
  end
end
