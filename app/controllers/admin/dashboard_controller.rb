class Admin::DashboardController < Admin::BaseController
  def show
    family_group = current_admin.family_group

    hoy = Date.current
    inicio_mes = hoy.beginning_of_month
    fin_mes = hoy.end_of_month

    @incomes_del_mes = Income.joins(:user)
                              .where(users: { family_group_id: family_group.id })
                              .where(date: inicio_mes..fin_mes)
                              .order(:date)

    @ingreso = @incomes_del_mes.sum(:amount)

    expenses_del_mes = Expense.where(family_group_id: family_group.id)
                               .where(date: inicio_mes..fin_mes)

    @consumo = expenses_del_mes.sum(:amount)
    @ahorro = @ingreso - @consumo

    @consumo_por_categoria = expenses_del_mes
      .joins(:category)
      .group("categories.name")
      .sum(:amount)

    @periodo = hoy.strftime("%B %Y")
  end
end
