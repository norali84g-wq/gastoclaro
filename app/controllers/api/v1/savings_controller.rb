class Api::V1::SavingsController < Api::V1::BaseController
  # Ingresos, consumo y ahorro de cada mes desde el primer movimiento hasta el mes en curso, con el
  # ahorro acumulado mes a mes. Es el detalle completo de lo que el panel resume en los últimos meses.
  def show
    incomes = totals_by_month(visible_incomes)
    expenses = totals_by_month(visible_expenses)

    render json: {
      savings_goal_percentage: current_user.family_group.savings_percentage,
      months: monthly_savings(incomes, expenses)
    }
  end

  private

  # Suma por mes ("YYYY-MM") de los montos de los registros.
  def totals_by_month(records)
    records.pluck(:date, :amount).each_with_object(Hash.new(0.to_d)) do |(date, amount), totals|
      totals[date.strftime("%Y-%m")] += amount
    end
  end

  def monthly_savings(incomes, expenses)
    first_month = (incomes.keys + expenses.keys).min
    return [] unless first_month

    accumulated = 0.to_d
    months = []
    month = Date.strptime(first_month, "%Y-%m")
    last_month = Date.current.beginning_of_month

    while month <= last_month
      key = month.strftime("%Y-%m")
      income = incomes[key]
      consumption = expenses[key]
      savings = income - consumption
      accumulated += savings

      months << { month: key, income: income, consumption: consumption,
                  savings: savings, accumulated: accumulated }
      month = month.next_month
    end

    months
  end
end
