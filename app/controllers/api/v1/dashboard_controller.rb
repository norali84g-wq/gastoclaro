class Api::V1::DashboardController < Api::V1::BaseController
  def show
    family_group = current_user.family_group

    hoy = Date.current
    inicio_mes = hoy.beginning_of_month
    fin_mes = hoy.end_of_month

    incomes_del_mes = Income.joins(:user)
                             .where(users: { family_group_id: family_group.id })
                             .where(date: inicio_mes..fin_mes)
                             .order(:date)

    ingreso = incomes_del_mes.sum(:amount)

    expenses_del_mes = Expense.where(family_group_id: family_group.id)
                               .where(date: inicio_mes..fin_mes)

    consumo = expenses_del_mes.sum(:amount)

    consumo_por_categoria = expenses_del_mes
      .joins(:category)
      .group("categories.name")
      .sum(:amount)

    ahorro = ingreso - consumo

    acumulado = 0
    ahorro_mensual = (5.downto(0)).map do |i|
      mes_inicio = hoy.beginning_of_month - i.months
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

      { mes: mes_inicio.strftime("%Y-%m"), ingreso: ingreso_mes, consumo: consumo_mes, ahorro: ahorro_mes, acumulado: acumulado }
    end

    render json: {
      periodo: hoy.strftime("%Y-%m"),
      ingreso: ingreso,
      consumo: consumo,
      ahorro: ahorro,
      meta_ahorro_porcentaje: family_group.savings_percentage,
      ingresos: incomes_del_mes.map { |i|
        { id: i.id, usuario: i.user.user, amount: i.amount, date: i.date }
      },
      consumo_por_categoria: consumo_por_categoria.map { |categoria, total|
        { categoria: categoria, total: total }
      },
      ahorro_mensual: ahorro_mensual
    }
  end
end
